// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'dartdoc/dartdoc.dart';
import 'dartdoc/dartdoc_options.dart';
import 'download_utils.dart';
import 'internal_model.dart';
import 'license.dart';
import 'logging.dart';
import 'messages.dart' as messages;
import 'model.dart';
import 'package_analyzer.dart' show InspectOptions;
import 'pana_cache.dart';
import 'pkg_resolution.dart';
import 'pubspec.dart';
import 'pubspec_io.dart';
import 'references/pubspec_urls.dart';
import 'repository/check_repository.dart';
import 'screenshots.dart';
import 'sdk_env.dart';
import 'tag/license_tags.dart';
import 'tag/pana_tags.dart';
import 'tag/tagger.dart';
import 'tool/run_constrained.dart';
import 'tool/webp_tool.dart';
import 'utils.dart' show getVersionListing, listFiles, withTempDir;

/// Shared (intermediate) results between different packages or versions.
/// External systems that may be independent of the archive content may be
/// stored here, e.g. repository and URL verification.
class SharedAnalysisContext {
  final PanaCache panaCache;
  final ToolEnvironment toolEnvironment;
  final InspectOptions options;
  final UrlChecker _urlChecker;

  SharedAnalysisContext({
    PanaCache? panaCache,
    required this.toolEnvironment,
    InspectOptions? options,
    UrlChecker? urlChecker,
  }) : panaCache = panaCache ?? PanaCache(),
       options = options ?? InspectOptions(),
       _urlChecker = urlChecker ?? UrlChecker();

  Future<UrlStatus> checkUrlStatus(String url) async {
    final cacheType = 'url';
    final cacheKey = url;
    final cachedData = await panaCache.readData(cacheType, cacheKey);
    if (cachedData != null) {
      return UrlStatus.fromJson(cachedData);
    }
    final status = await _urlChecker.checkStatus(url);
    await panaCache.writeData(cacheType, cacheKey, status.toJson());
    return status;
  }

  Future<VerifiedRepository> verifyRepository(
    String package,
    String? repositoryOrHomepage,
  ) async {
    repositoryOrHomepage = repositoryOrHomepage?.trim();
    if (repositoryOrHomepage == null || repositoryOrHomepage.isEmpty) {
      return VerifiedRepository(
        status: RepositoryStatus.unspecified,
        verificationFailure: 'Repository URL is missing.',
      );
    }
    final cacheType = 'repository';
    final cacheKey = '$package/$repositoryOrHomepage';
    final cachedData = await panaCache.readData(cacheType, cacheKey);
    if (cachedData != null) {
      return VerifiedRepository.fromJson(cachedData);
    }
    final repository = await checkRepository(
      sharedContext: this,
      packageName: package,
      sourceUrl: repositoryOrHomepage,
    );
    await panaCache.writeData(cacheType, cacheKey, repository.toJson());
    return repository;
  }
}

/// Calculates and stores the intermediate analysis and processing results that
/// are required for the final report.
class PackageContext {
  final SharedAnalysisContext sharedContext;
  final String packageDir;
  final errors = <String>[];
  final urlProblems = <String, String>{};
  final _stopwatch = Stopwatch();

  Pubspec? _pubspec;

  PackageContext({required this.sharedContext, required this.packageDir}) {
    _stopwatch.start();
  }

  ToolEnvironment get toolEnvironment => sharedContext.toolEnvironment;
  InspectOptions get options => sharedContext.options;

  /// Returns the remaining time budget, or a very small but positive duration
  /// if we are already above the total budget.
  ///
  /// Returns `null` if the total budget was not specified.
  Duration? _remainingTimeBudget() {
    if (options.totalTimeout == null) {
      return null;
    }
    final threshold = const Duration(seconds: 1);
    final remaining = options.totalTimeout! - _stopwatch.elapsed;
    return remaining > threshold ? remaining : threshold;
  }

  late final Version currentSdkVersion = Version.parse(
    toolEnvironment.runtimeInfo.sdkVersion,
  );

  Pubspec get pubspec {
    if (_pubspec != null) return _pubspec!;
    try {
      _pubspec = pubspecFromDir(packageDir);
    } catch (e, st) {
      log.info('Unable to read pubspec.yaml', e, st);
      rethrow;
    }
    return _pubspec!;
  }

  late final bool usesFlutter = pubspec.usesFlutter;

  Future<bool> resolveDependencies() async =>
      (await resolveErrorMessage) == null;

  late final resolveErrorMessage = () async {
    String? stderr;
    try {
      await outdated;
      return null;
    } on ToolException catch (e) {
      stderr = e.result?.stderr.asString ?? e.message;
    } catch (e) {
      stderr = e.toString();
    }

    final errEntries = PubEntry.parse(
      stderr,
    ).where((e) => e.header == 'ERR').join('\n');
    final message = errEntries.isNotEmpty
        ? errEntries
        : stderr
              .split('\n')
              .map((e) => e.trim())
              .where((l) => l.isNotEmpty)
              .take(2)
              .join('\n');

    // 1: Version constraint issue with direct or transitive dependencies.
    //
    // 2: Code in a git repository could change or disappear.
    final isUserProblem =
        message.contains('version solving failed') || // 1
        pubspec.hasGitDependency || // 2
        message.contains('Git error.'); // 2

    if (!isUserProblem) {
      log.severe('`dart pub outdated` failed.\n$message'.trim());
    }

    // Note: calling `flutter pub pub` ensures we get the raw `pub` output.
    // TODO: get the actual command from [ToolException].
    final cmd = usesFlutter ? 'flutter pub outdated' : 'dart pub outdated';
    final errorMessage = message.isEmpty
        ? 'Running `$cmd` failed.'
        : 'Running `$cmd` failed with the following output:\n\n'
              '```\n$message\n```\n';
    errors.add(errorMessage);
    return errorMessage;
  }();

  /// Runs `pub downgrade` and then static analysis.
  /// Returns `null` when no issues found or a String description of the issues.
  late final downgradeAnalysisErrorMessage = () async {
    try {
      log.info('Analyzing pub downgrade...');
      final tool = usesFlutter ? 'flutter' : 'dart';
      var pr = await toolEnvironment.runPub(
        packageDir,
        usesFlutter: usesFlutter,
        command: 'downgrade',
      );
      // try to downgrade without the dev-dependencies
      if (pr.wasError) {
        pr = await toolEnvironment.runPub(
          packageDir,
          usesFlutter: usesFlutter,
          command: 'downgrade',
          stripAllDevDependencies: true,
        );
      }
      if (pr.wasError) {
        log.info('[pub-downgrade-error]');
        log.info(pr.asJoinedOutput);
        log.info('Re-running with verbose output:');
        final rerun = await toolEnvironment.runPub(
          packageDir,
          usesFlutter: usesFlutter,
          command: 'downgrade',
          verbose: true,
          stripAllDevDependencies: true,
        );
        log.info(rerun.asJoinedOutput);
        return '`$tool pub downgrade` failed with:\n\n```\n${pr.asTrimmedOutput}\n```\n';
      }

      final problems = await _staticAnalysis();
      final errors = problems.where((e) => e.isError).toList();
      if (errors.isEmpty) {
        log.info('[pub-downgrade-success]');
        return null;
      } else {
        final issueLines = errors
            .take(3)
            .map(
              (cp) =>
                  ' - `${cp.errorCode}` - `${cp.file}:${cp.line}:${cp.col}` - ${cp.description}\n',
            )
            .join();
        final issueLabel = errors.length == 1 ? 'error' : 'errors';
        log.info('[pub-downgrade-failed]');
        return 'downgrade analysis failed failed with ${errors.length} $issueLabel:\n\n$issueLines';
      }
    } on ToolException catch (e, st) {
      log.info('[pub-downgrade-error]', e, st);
      return 'downgrade analysis failed with:\n${e.message}';
    } finally {
      try {
        final pr = await toolEnvironment.runPub(
          packageDir,
          usesFlutter: usesFlutter,
          command: 'upgrade',
        );
        if (pr.wasError) {
          log.info('Re-running with verbose output:');
          final rerun = await toolEnvironment.runPub(
            packageDir,
            usesFlutter: usesFlutter,
            command: 'upgrade',
            verbose: true,
          );
          log.info(rerun.asJoinedOutput);
        }
      } on ToolException catch (e, st) {
        errors.add('`dart upgrade` failed');
        log.warning('dart upgrade failed', e, st);
      }
    }
  }();

  late final Future<List<String>> _dartFiles = () async {
    final results = <String>[];
    final fileList = listFiles(packageDir, deleteBadExtracted: true);
    await for (final file in fileList) {
      final isInBin = p.isWithin('bin', file);
      final isInLib = p.isWithin('lib', file);
      final isDart = file.endsWith('.dart');
      if (isDart && (isInLib || isInBin)) {
        results.add(file);
      }
    }
    return results;
  }();

  late final Future<AnalyzeToolResult> staticAnalysis = () async {
    List<CodeProblem>? items;
    final tags = <String>[];
    final explanations = <Explanation>[];
    final dartFiles = await _dartFiles;

    if (!await resolveDependencies()) {
      tags.add(PanaTags.hasError);
    } else if (dartFiles.isEmpty) {
      items = [];
    } else {
      log.info('Analyzing package...');
      // Try to resolve dev_dependencies for analysis, falling back to direct dependencies.
      await toolEnvironment.runPub(
        packageDir,
        usesFlutter: usesFlutter,
        command: 'get',
      );
      try {
        items = await _staticAnalysis();
      } on ToolException catch (e) {
        errors.add(messages.runningDartAnalyzerFailed(usesFlutter, e.message));
        return AnalyzeToolResult.toolError(e);
      }
    }

    if (items != null && !items.any((item) => item.isError)) {
      final tagger = Tagger(
        packageDir,
        dartSdkPath: toolEnvironment.dartSdkPath,
      );
      // TODO: refactor these methods to return the tags+explanations
      tagger.sdkTags(tags, explanations);
      tagger.platformTags(tags, explanations);
      tagger.runtimeTags(tags, explanations);
      tagger.flutterPluginTags(tags, explanations);
      tagger.nullSafetyTags(tags, explanations);
      tagger.wasmReadyTag(tags, explanations);
      tagger.swiftPackageManagerPluginTag(tags, explanations);
      tagger.kotlinPluginTag(tags, explanations);
      if (currentSdkVersion.major >= 3) {
        tags.add(PanaTags.isDart3Compatible);
      }
    } else {
      tags.add(PanaTags.hasError);
    }

    return AnalyzeToolResult(
      items: items,
      tags: tags,
      explanations: explanations,
    );
  }();

  Future<List<CodeProblem>> _staticAnalysis() async {
    return await toolEnvironment.runAnalyze(
      packageDir,
      usesFlutter,
      inspectOptions: options,
    );
  }

  late final Future<Outdated> outdated = toolEnvironment.runPubOutdated(
    packageDir,
    args: [
      '--json',
      '--up-to-date',
      '--no-dev-dependencies',
      '--no-dependency-overrides',
    ],
    usesFlutter: usesFlutter,
  );

  late final Future<List<ScreenshotResult>> screenshots = processAllScreenshots(
    pubspec.screenshots,
    packageDir,
    WebpTool(toolEnvironment.sandboxRunner),
  );

  late final pubspecAllowsCurrentSdk =
      pubspec.dartSdkConstraint != null &&
      pubspec.dartSdkConstraint!.allows(currentSdkVersion);

  late final pubspecUrlsWithIssues = checkPubspecUrls(this);

  late final repository = sharedContext.verifyRepository(
    pubspec.name,
    pubspec.repositoryOrHomepage,
  );

  late final licenses = detectLicenseInDir(
    packageDir,
    licenseDataDir: options.licenseDataDir,
  );
  late final licenceTags = () async {
    return LicenseTags.fromLicenses(await licenses);
  }();

  late final Future<DartdocResult> dartdocResult = () async {
    final dartdocOutputDir = options.dartdocOutputDir;
    if (dartdocOutputDir == null) {
      return DartdocResult.skipped();
    }
    if (await resolveDependencies()) {
      var timeout = options.dartdocTimeout;
      final rtb = _remainingTimeBudget();
      if (rtb != null && rtb < timeout) {
        timeout = rtb;
      }
      await normalizeDartdocOptionsYaml(packageDir);
      try {
        final pr = await toolEnvironment.dartdoc(
          packageDir,
          dartdocOutputDir,
          timeout: timeout,
          usesFlutter: usesFlutter,
        );
        if (pr.wasTimeout) {
          log.warning('`dartdoc` timed out:\n${pr.asJoinedOutput}');
          return DartdocResult.error(
            '`dartdoc` could not complete in $timeout.',
          );
        }
        if (pr.wasError) {
          log.warning('`dartdoc` failed:\n${pr.asJoinedOutput}');
          return DartdocResult.error(pr.asTrimmedOutput);
        }

        final hasIndexHtml = await File(
          p.join(dartdocOutputDir, 'index.html'),
        ).exists();
        final hasIndexJson = await File(
          p.join(dartdocOutputDir, 'index.json'),
        ).exists();
        if (!hasIndexHtml || !hasIndexJson) {
          log.warning('`dartdoc` failed:\n${pr.asJoinedOutput}');
          return DartdocResult.error(
            '`dartdoc` did not create expected output files.',
          );
        }
        log.info('`dartdoc` completed:\n${pr.asJoinedOutput}');
        return DartdocResult.success();
      } catch (e, st) {
        log.severe('Could not run dartdoc.', e, st);
        return DartdocResult.error('Could not run `dartdoc`: $e');
      }
    } else {
      return DartdocResult.error(
        'Dependency resolution failed, unable to run `dartdoc`.',
      );
    }
  }();

  late final dartdocPubData = () async {
    final dr = await dartdocResult;
    if (dr.wasSuccessful) {
      return await generateAndSavePubDataJson(options.dartdocOutputDir!);
    } else {
      return null;
    }
  }();

  late final executablesInBinDirectory = () async {
    final binDir = Directory(p.join(packageDir, 'bin'));
    if (!await binDir.exists()) {
      return <String>[];
    }
    final executables = <String>[];
    final entries = await binDir.list(followLinks: false).toList();
    for (final file in entries.whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      executables.add(p.basename(file.path));
    }
    return executables;
  }();

  late final Future<ApiDiffToolResult> apiDiffResult = () async {
    if (!options.runApiDiff) {
      return ApiDiffToolResult.skipped();
    }
    if (!await resolveDependencies()) {
      return ApiDiffToolResult.error(
        'Dependency resolution failed, unable to run `api_summary`.',
      );
    }

    final currentVersion = pubspec.version;
    if (currentVersion == null) {
      return ApiDiffToolResult.noPreviousVersion();
    }
    final Version? previousVersion;
    if (options.apiDiffOldVersion != null &&
        options.apiDiffOldVersion!.isNotEmpty) {
      previousVersion = Version.parse(options.apiDiffOldVersion!);
    } else {
      previousVersion = await _findPreviousPublishedVersion(
        pubspec.name,
        currentVersion,
      );
    }

    if (previousVersion == null) {
      if (options.resourcesOutputDir != null) {
        final apiJsonOut = p.join(
          p.dirname(options.resourcesOutputDir!),
          'api.json',
        );
        try {
          await toolEnvironment.apiSummaryExtract(
            packageDir: packageDir,
            outputFilePath: apiJsonOut,
            timeout: const Duration(minutes: 2),
          );
        } catch (e, st) {
          log.warning('Could not extract api.json for first version.', e, st);
        }
      }
      return ApiDiffToolResult.noPreviousVersion();
    }

    return await withTempDir((tempDir) async {
      final oldPkgDir = p.join(tempDir, 'old');
      final outDir = p.join(tempDir, 'out');
      await Directory(outDir).create(recursive: true);
      final reportFilePath = p.join(outDir, 'api_diff.json');
      final newSummaryTempPath = p.join(outDir, 'api.json');

      try {
        log.info(
          'Unpacking ${pubspec.name}:$previousVersion for API diff comparison...',
        );
        await toolEnvironment.unpack(
          package: pubspec.name,
          version: previousVersion.toString(),
          pubHostedUrl: options.pubHostedUrl,
          outputDir: oldPkgDir,
        );

        final oldPubspec = Pubspec.parseYaml(
          await File(p.join(oldPkgDir, 'pubspec.yaml')).readAsString(),
        );
        final oldPubGet = await toolEnvironment.runPub(
          oldPkgDir,
          usesFlutter: oldPubspec.usesFlutter,
          command: 'get',
          stripAllDevDependencies: true,
        );
        if (oldPubGet.wasError) {
          log.warning(
            'Could not resolve previous version $previousVersion for API diff:\n${oldPubGet.asJoinedOutput}',
          );
          if (options.resourcesOutputDir != null) {
            final destPath = p.join(
              p.dirname(options.resourcesOutputDir!),
              'api.json',
            );
            try {
              await toolEnvironment.apiSummaryExtract(
                packageDir: packageDir,
                outputFilePath: destPath,
                timeout: const Duration(minutes: 2),
              );
            } catch (e, st) {
              log.warning(
                'Could not extract api.json for current version.',
                e,
                st,
              );
            }
          }
          return ApiDiffToolResult.error(
            'Could not resolve previous version `$previousVersion`:\n\n```\n${oldPubGet.asTrimmedOutput}\n```',
          );
        }

        // Ensure current package is resolved as well (no-op if already resolved).
        final newPackageConfig = File(
          p.join(packageDir, '.dart_tool', 'package_config.json'),
        );
        if (!await newPackageConfig.exists()) {
          final newPubGet = await toolEnvironment.runPub(
            packageDir,
            usesFlutter: usesFlutter,
            command: 'get',
            stripAllDevDependencies: true,
          );
          if (newPubGet.wasError) {
            return ApiDiffToolResult.error(
              'Could not resolve current version `$currentVersion`:\n\n```\n${newPubGet.asTrimmedOutput}\n```',
            );
          }
        }

        var timeout = const Duration(minutes: 3);
        final rtb = _remainingTimeBudget();
        if (rtb != null && rtb < timeout) {
          timeout = rtb;
        }

        log.info(
          'Running api_summary diff (${pubspec.name} $previousVersion -> $currentVersion)...',
        );
        final pr = await toolEnvironment.apiSummaryDiff(
          oldPackageDir: oldPkgDir,
          newPackageDir: packageDir,
          reportFilePath: reportFilePath,
          newSummaryOutputPath: newSummaryTempPath,
          timeout: timeout,
        );
        log.info(
          'Finished api_summary diff (${pubspec.name} $previousVersion -> $currentVersion).',
        );

        if (options.resourcesOutputDir != null &&
            await File(newSummaryTempPath).exists()) {
          final destPath = p.join(
            p.dirname(options.resourcesOutputDir!),
            'api.json',
          );
          await File(newSummaryTempPath).copy(destPath);
        }

        if (pr.wasTimeout) {
          log.warning('`api_summary` timed out:\n${pr.asJoinedOutput}');
          return ApiDiffToolResult.error(
            '`api_summary` could not complete in $timeout.',
          );
        }

        final reportFile = File(reportFilePath);
        if (pr.wasError || !await reportFile.exists()) {
          log.warning('`api_summary` failed:\n${pr.asJoinedOutput}');
          return ApiDiffToolResult.error(
            '`api_summary` failed:\n\n```\n${pr.asTrimmedOutput}\n```',
          );
        }

        final reportJson =
            json.decode(await reportFile.readAsString())
                as Map<String, Object?>;
        final summary = _parseApiSummaryDiffReport(
          reportJson,
          previousVersion: previousVersion!,
          currentVersion: currentVersion,
        );
        return ApiDiffToolResult.success(summary);
      } catch (e, st) {
        log.warning('Could not run api_summary diff.', e, st);
        return ApiDiffToolResult.error('Could not run `api_summary`: $e');
      }
    });
  }();

  Future<Version?> _findPreviousPublishedVersion(
    String packageName,
    Version currentVersion,
  ) async {
    final pubHostedUrl =
        options.pubHostedUrl ?? Platform.environment['PUB_HOSTED_URL'];
    final pubHostedUri = (pubHostedUrl != null && pubHostedUrl.isNotEmpty)
        ? Uri.tryParse(pubHostedUrl)
        : null;
    try {
      final rawListing = await getVersionListing(
        packageName,
        pubHostedUrl: pubHostedUri,
      );
      final decoded = json.decode(rawListing);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final versions = decoded['versions'];
      if (versions is! List<Object?>) {
        return null;
      }

      final candidates = <Version>[];
      for (final entry in versions) {
        if (entry is Map<String, Object?>) {
          if (entry['retracted'] == true) {
            continue;
          }
          final vStr = entry['version'];
          if (vStr is String) {
            try {
              final parsed = Version.parse(vStr);
              if (parsed < currentVersion) {
                candidates.add(parsed);
              }
            } on FormatException {
              // ignore malformed version
            }
          }
        }
      }
      if (candidates.isEmpty) {
        return null;
      }
      candidates.sort();
      if (!currentVersion.isPreRelease) {
        final stableCandidates = candidates
            .where((v) => !v.isPreRelease)
            .toList();
        if (stableCandidates.isNotEmpty) {
          return stableCandidates.last;
        }
      }
      return candidates.last;
    } catch (e) {
      log.info(
        'Unable to fetch version listing for $packageName to compute API diff: $e',
      );
      return null;
    }
  }
}

ApiDiffSummary _parseApiSummaryDiffReport(
  Map<String, Object?> reportJson, {
  required Version previousVersion,
  required Version currentVersion,
}) {
  final toolVersion = reportJson['toolVersion'] as String?;
  final breakingChanges = [
    if (reportJson['breakingChanges'] case final List<Object?> list)
      for (final item in list)
        if (item is Map<String, Object?>) ApiChange.fromJson(item),
  ];
  final nonBreakingChanges = [
    if (reportJson['nonBreakingChanges'] case final List<Object?> list)
      for (final item in list)
        if (item is Map<String, Object?>) ApiChange.fromJson(item),
  ];
  final textDiff = reportJson['textDiff'] as String?;

  final hasBreaking = breakingChanges.isNotEmpty;
  final hasMinor = nonBreakingChanges.any((c) => c.type == 'minor');
  final hasPatch = nonBreakingChanges.isNotEmpty && !hasMinor;

  final String requiredBump;
  final Version minimumExpected;
  if (hasBreaking) {
    requiredBump = 'major';
    minimumExpected = previousVersion.nextBreaking;
  } else if (hasMinor) {
    requiredBump = 'minor';
    minimumExpected = previousVersion.major > 0
        ? previousVersion.nextMinor
        : previousVersion.nextPatch;
  } else if (hasPatch) {
    requiredBump = 'patch';
    minimumExpected = previousVersion.nextPatch;
  } else {
    requiredBump = 'none';
    minimumExpected = previousVersion;
  }

  final bool isSufficient;
  if (currentVersion.isPreRelease) {
    isSufficient = currentVersion > previousVersion;
  } else if (previousVersion.isPreRelease) {
    final prevBase = Version(
      previousVersion.major,
      previousVersion.minor,
      previousVersion.patch,
    );
    isSufficient =
        currentVersion >= prevBase && currentVersion >= minimumExpected;
  } else {
    isSufficient = currentVersion >= minimumExpected;
  }

  return ApiDiffSummary(
    previousVersion: previousVersion.toString(),
    currentVersion: currentVersion.toString(),
    requiredVersionBump: requiredBump,
    minimumExpectedVersion: minimumExpected.toString(),
    isVersionIncrementSufficient: isSufficient,
    toolVersion: toolVersion,
    breakingChanges: breakingChanges,
    nonBreakingChanges: nonBreakingChanges,
    textDiff: (textDiff != null && textDiff.isNotEmpty) ? textDiff : null,
  );
}

class ApiDiffToolResult {
  final bool wasRun;
  final ApiDiffSummary? summary;
  final String? errorReason;

  ApiDiffToolResult.skipped()
    : wasRun = false,
      summary = null,
      errorReason = null;

  ApiDiffToolResult.noPreviousVersion()
    : wasRun = true,
      summary = null,
      errorReason = null;

  ApiDiffToolResult.success(this.summary) : wasRun = true, errorReason = null;

  ApiDiffToolResult.error(this.errorReason) : wasRun = true, summary = null;
}

class DartdocResult {
  final bool wasRunning;
  final String? errorReason;

  DartdocResult.error(this.errorReason) : wasRunning = true;

  DartdocResult.skipped() : wasRunning = false, errorReason = null;

  DartdocResult.success() : wasRunning = true, errorReason = null;

  bool get wasSuccessful => wasRunning && errorReason == null;
}
