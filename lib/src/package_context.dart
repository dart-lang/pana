// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'code_problem.dart';
import 'dartdoc/dartdoc.dart';
import 'dartdoc/dartdoc_options.dart';
import 'download_utils.dart';
import 'internal_model.dart';
import 'license.dart';
import 'logging.dart';
import 'messages.dart' as messages;
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
import 'utils.dart' show listFiles, listFocusDirs;

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
  })  : panaCache = panaCache ?? PanaCache(),
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

  Future<VerifiedRepository?> verifyRepository(
    String package,
    String? repositoryOrHomepage,
  ) async {
    if (repositoryOrHomepage == null) {
      return null;
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
    if (repository != null) {
      await panaCache.writeData(cacheType, cacheKey, repository.toJson());
    }
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

  PackageContext({
    required this.sharedContext,
    required this.packageDir,
  }) {
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

  late final Version currentSdkVersion =
      Version.parse(toolEnvironment.runtimeInfo.sdkVersion);

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

    final errEntries =
        PubEntry.parse(stderr).where((e) => e.header == 'ERR').join('\n');
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
    final isUserProblem = message.contains('version solving failed') || // 1
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
      final pr = await toolEnvironment.runPub(
        packageDir,
        usesFlutter: usesFlutter,
        command: 'downgrade',
      );
      if (pr.exitCode != 0) {
        log.info('[pub-downgrade-error]');
        log.info(pr.asJoinedOutput);
        return '`$tool pub downgrade` failed with:\n\n```\n${pr.asTrimmedOutput}\n```\n';
      }

      final problems = await _staticAnalysis(packageDir: packageDir);
      final errors = problems.where((e) => e.isError).toList();
      if (errors.isEmpty) {
        log.info('[pub-downgrade-success]');
        return null;
      } else {
        final issueLines = errors
            .take(3)
            .map((cp) =>
                ' - `${cp.errorCode}` - `${cp.file}:${cp.line}:${cp.col}` - ${cp.description}\n')
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
        await toolEnvironment.runPub(packageDir,
            usesFlutter: usesFlutter, command: 'upgrade');
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
      try {
        items = await _staticAnalysis(packageDir: packageDir);
      } on ToolException catch (e) {
        errors.add(messages.runningDartAnalyzerFailed(usesFlutter, e.message));
        return AnalyzeToolResult.toolError(e);
      }
    }

    if (items != null && !items.any((item) => item.isError)) {
      final tagger = Tagger(packageDir);
      // TODO: refactor these methods to return the tags+explanations
      tagger.sdkTags(tags, explanations);
      tagger.platformTags(tags, explanations);
      tagger.runtimeTags(tags, explanations);
      tagger.flutterPluginTags(tags, explanations);
      tagger.nullSafetyTags(tags, explanations);
      tagger.wasmReadyTag(tags, explanations);
      tagger.swiftPackageManagerPluginTag(tags, explanations);
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

  Future<List<CodeProblem>> _staticAnalysis({
    required String packageDir,
  }) async {
    final dirs = await listFocusDirs(packageDir);
    final problems = <CodeProblem>[];
    for (final dir in dirs) {
      final output = await toolEnvironment.runAnalyzer(
        packageDir,
        dir,
        usesFlutter,
        inspectOptions: options,
      );
      final list = LineSplitter.split(output)
          .map((s) => parseCodeProblem(s, projectDir: packageDir))
          .nonNulls
          .toSet()
          .toList();
      list.sort();
      problems.addAll(list);
    }
    return problems;
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

  late final Future<List<ScreenshotResult>> screenshots =
      processAllScreenshots(pubspec.screenshots, packageDir);

  late final pubspecAllowsCurrentSdk = pubspec.dartSdkConstraint != null &&
      pubspec.dartSdkConstraint!.allows(currentSdkVersion);

  late final pubspecUrlsWithIssues = checkPubspecUrls(this);

  late final repository = sharedContext.verifyRepository(
      pubspec.name, pubspec.repositoryOrHomepage);

  late final licenses = detectLicenseInDir(packageDir);
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
              '`dartdoc` could not complete in $timeout.');
        }
        if (pr.wasError) {
          log.warning('`dartdoc` failed:\n${pr.asJoinedOutput}');
          return DartdocResult.error(pr.asTrimmedOutput);
        }

        final hasIndexHtml =
            await File(p.join(dartdocOutputDir, 'index.html')).exists();
        final hasIndexJson =
            await File(p.join(dartdocOutputDir, 'index.json')).exists();
        if (!hasIndexHtml || !hasIndexJson) {
          log.warning('`dartdoc` failed:\n${pr.asJoinedOutput}');
          return DartdocResult.error(
              '`dartdoc` did not create expected output files.');
        }
        log.info('`dartdoc` completed:\n${pr.asJoinedOutput}');
        return DartdocResult.success();
      } catch (e, st) {
        log.severe('Could not run dartdoc.', e, st);
        return DartdocResult.error('Could not run `dartdoc`: $e');
      }
    } else {
      return DartdocResult.error(
          'Dependency resolution failed, unable to run `dartdoc`.');
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
    final entries = await binDir.list().toList();
    for (final file in entries.whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      executables.add(p.basename(file.path));
    }
    return executables;
  }();
}

class DartdocResult {
  final bool wasRunning;
  final String? errorReason;

  DartdocResult.error(
    this.errorReason,
  ) : wasRunning = true;

  DartdocResult.skipped()
      : wasRunning = false,
        errorReason = null;

  DartdocResult.success()
      : wasRunning = true,
        errorReason = null;

  bool get wasSuccessful => wasRunning && errorReason == null;
}
