// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'code_problem.dart';
import 'download_utils.dart';
import 'health.dart';
import 'library_scanner.dart';
import 'license.dart';
import 'logging.dart';
import 'maintenance.dart';
import 'messages.dart' as messages;
import 'model.dart';
import 'pkg_resolution.dart';
import 'platform.dart';
import 'pubspec.dart';
import 'sdk_env.dart';
import 'utils.dart';

enum Verbosity {
  compact,
  normal,
  verbose,
}

class InspectOptions {
  final Verbosity verbosity;
  final bool deleteTemporaryDirectory;
  final String pubHostedUrl;
  final String dartdocOutputDir;
  final int dartdocRetry;
  final Duration dartdocTimeout;
  final bool isInternal;
  final int lineLength;

  InspectOptions({
    this.verbosity = Verbosity.normal,
    this.deleteTemporaryDirectory = true,
    this.pubHostedUrl,
    this.dartdocOutputDir,
    this.dartdocRetry = 0,
    this.dartdocTimeout,
    this.isInternal = false,
    this.lineLength,
  });
}

class PackageAnalyzer {
  final ToolEnvironment _toolEnv;
  final UrlChecker _urlChecker;

  PackageAnalyzer(this._toolEnv, {UrlChecker urlChecker})
      : _urlChecker = urlChecker ?? UrlChecker();

  static Future<PackageAnalyzer> create(
      {String sdkDir, String flutterDir, String pubCacheDir}) async {
    return PackageAnalyzer(await ToolEnvironment.create(
        dartSdkDir: sdkDir,
        flutterSdkDir: flutterDir,
        pubCacheDir: pubCacheDir));
  }

  Future<Summary> inspectPackage(
    String package, {
    String version,
    InspectOptions options,
    Logger logger,
  }) async {
    options ??= InspectOptions();
    return withLogger(() async {
      log.info('Downloading package $package ${version ?? 'latest'}');
      String packageDir;
      Directory tempDir;
      if (version != null) {
        tempDir = await downloadPackage(package, version,
            pubHostedUrl: options.pubHostedUrl);
        packageDir = tempDir?.path;
      }
      if (packageDir == null) {
        var pkgInfo = await _toolEnv.getLocation(package, version: version);
        packageDir = pkgInfo.location;
      }
      try {
        return await _inspect(packageDir, options);
      } finally {
        if (options.deleteTemporaryDirectory) {
          await tempDir?.delete(recursive: true);
        } else {
          log.warning(
              'Temporary directory was not deleted: `${tempDir.path}`.');
        }
      }
    }, logger: logger);
  }

  Future<Summary> inspectDir(String packageDir, {InspectOptions options}) {
    options ??= InspectOptions();
    return _inspect(packageDir, options);
  }

  Future<Summary> _inspect(String pkgDir, InspectOptions options) async {
    final totalStopwatch = Stopwatch()..start();
    final resolveProcessStopwatch = Stopwatch();
    final analyzeProcessStopwatch = Stopwatch();
    final formatProcessStopwatch = Stopwatch();
    final suggestions = <Suggestion>[];

    var dartFiles =
        await listFiles(pkgDir, endsWith: '.dart', deleteBadExtracted: true)
            .where((file) => file.startsWith('bin/') || file.startsWith('lib/'))
            .toList();

    log.info('Parsing pubspec.yaml...');
    Pubspec pubspec;
    try {
      pubspec = Pubspec.parseFromDir(pkgDir);
    } catch (e, st) {
      log.info('Unable to read pubspec.yaml', e, st);
      suggestions.add(pubspecParseError(e));
      return Summary(
        runtimeInfo: _toolEnv.runtimeInfo,
        packageName: null,
        packageVersion: null,
        pubspec: options.verbosity == Verbosity.compact ? null : pubspec,
        pkgResolution: null,
        dartFiles: null,
        platform: null,
        licenses: null,
        health: null,
        maintenance: null,
        suggestions: suggestions,
        stats: null,
      );
    }
    if (pubspec.hasUnknownSdks) {
      suggestions.add(Suggestion.error(
          SuggestionCode.pubspecSdkUnknown,
          'Check SDKs in `pubspec.yaml`.',
          'The following unknown SDKs are in `pubspec.yaml`:\n'
          '  `${pubspec.unknownSdks}`.\n\n'
          '`pana` doesn’t recognize them; please remove the `sdk` entry or '
          '[report the issue](https://github.com/dart-lang/pana/issues).'));
    }

    final package = pubspec.name;
    final usesFlutter = pubspec.usesFlutter;

    formatProcessStopwatch.start();
    Set<String> unformattedFiles;
    try {
      unformattedFiles = SplayTreeSet<String>.from(
          await _toolEnv.filesNeedingFormat(pkgDir, usesFlutter,
              lineLength: options.lineLength));

      assert(unformattedFiles.every((f) => dartFiles.contains(f)),
          'dartfmt should only return Dart files');
    } catch (e, stack) {
      final errorMsg = LineSplitter.split(e.toString()).take(10).join('\n');
      final isUserProblem = errorMsg.contains(
              'Could not format because the source could not be parsed') ||
          errorMsg.contains('The formatter produced unexpected output.');
      if (!isUserProblem) {
        log.severe('`dartfmt` failed.\n$errorMsg', e, stack);
      }

      suggestions.add(Suggestion.error(
          SuggestionCode.dartfmtAborted,
          messages.makeSureDartfmtRuns(usesFlutter),
          messages.runningDartfmtFailed(usesFlutter, errorMsg)));
    }
    formatProcessStopwatch.stop();

    resolveProcessStopwatch.start();
    final upgrade = await _toolEnv.runUpgrade(pkgDir, usesFlutter);
    resolveProcessStopwatch.stop();

    PkgResolution pkgResolution;
    if (upgrade.exitCode == 0) {
      try {
        pkgResolution = createPkgResolution(pubspec, upgrade.stdout as String,
            path: pkgDir);
      } catch (e, stack) {
        log.severe('Problem with pub upgrade', e, stack);
        //(TODO)kevmoo - should add a helper that handles logging exceptions
        //  and writing to issues in one go.

        final cmd =
            usesFlutter ? 'flutter packages pub upgrade' : 'pub upgrade';
        suggestions.add(Suggestion.error(
            SuggestionCode.pubspecDependenciesFailedToResolve,
            'Fix dependencies in `pubspec.yaml`.',
            'Running `$cmd` failed with the following output:\n\n'
            '```\n$e\n```\n'));
      }
    } else {
      String message;
      if (upgrade.exitCode > 0) {
        message = PubEntry.parse(upgrade.stderr as String)
            .where((e) => e.header == 'ERR')
            .join('\n');
      } else {
        message = LineSplitter.split(upgrade.stderr as String).first;
      }

      // 1: Version constraint issue with direct or transitive dependencies.
      //
      // 2: Code in a git repository could change or disappear.
      final isUserProblem = message.contains('version solving failed') || // 1
          pubspec.hasGitDependency || // 2
          message.contains('Git error.'); // 2

      if (!isUserProblem) {
        log.severe('`pub upgrade` failed.\n$message'.trim());
      }

      final cmd = usesFlutter ? 'flutter packages pub upgrade' : 'pub upgrade';
      suggestions.add(Suggestion.error(
          SuggestionCode.pubspecDependenciesFailedToResolve,
          'Fix dependencies in `pubspec.yaml`.',
          message.isEmpty
              ? 'Running `$cmd` failed.'
              : 'Running `$cmd` failed with the following output:\n\n'
              '```\n$message\n```\n'));
    }

    Map<String, List<String>> allDirectLibs;
    Map<String, List<String>> allTransitiveLibs;
    Set<String> reachableLibs;

    LibraryScanner libraryScanner;

    List<CodeProblem> analyzerItems;

    bool dartdocSuccessful;
    if (pkgResolution != null && options.dartdocOutputDir != null) {
      for (var i = 0; i <= options.dartdocRetry; i++) {
        try {
          final r = await _toolEnv.dartdoc(
            pkgDir,
            options.dartdocOutputDir,
            validateLinks: i == 0,
            timeout: options.dartdocTimeout,
          );
          dartdocSuccessful = r.wasSuccessful;
          if (!r.wasTimeout) {
            break;
          }
        } catch (e, st) {
          log.severe('Could not run dartdoc.', e, st);
        }
      }
    }

    if (pkgResolution != null) {
      try {
        var overrides = [
          LibraryOverride.webSafeIO('package:http/http.dart'),
          LibraryOverride.webSafeIO('package:http/browser_client.dart'),
          LibraryOverride.webSafeIO(
              'package:package_resolver/package_resolver.dart'),
        ];

        libraryScanner =
            LibraryScanner(_toolEnv.dartSdkDir, pkgDir, overrides: overrides);
        assert(libraryScanner.packageName == package);
      } catch (e, stack) {
        log.severe('Could not create LibraryScanner', e, stack);
        suggestions.add(Suggestion.bug(SuggestionCode.exceptionInLibraryScanner,
            'LibraryScanner creation failed.', e, stack));
      }

      if (libraryScanner != null) {
        try {
          log.info('Scanning direct dependencies...');
          allDirectLibs = await libraryScanner.scanDirectLibs();
        } catch (e, st) {
          log.severe('Error scanning direct libraries', e, st);
          suggestions.add(Suggestion.bug(
              SuggestionCode.exceptionInLibraryScanner,
              'Error scanning direct libraries.',
              e,
              st));
        }
        try {
          log.info('Scanning transitive dependencies...');
          allTransitiveLibs = await libraryScanner.scanTransitiveLibs();
          reachableLibs = _reachableLibs(allTransitiveLibs);
        } catch (e, st) {
          log.severe('Error scanning transitive libraries', e, st);
          suggestions.add(Suggestion.bug(
              SuggestionCode.exceptionInLibraryScanner,
              'Error scanning transitive libraries.',
              e,
              st));
        }
      }

      if (dartFiles.isNotEmpty) {
        analyzeProcessStopwatch.start();
        try {
          analyzerItems = await _pkgAnalyze(pkgDir, usesFlutter);
        } on ArgumentError catch (e) {
          if (e.toString().contains('No dart files found at: .')) {
            log.warning('`dartanalyzer` found no files to analyze.');
          } else {
            suggestions.add(Suggestion.error(
                SuggestionCode.dartanalyzerAborted,
                messages.makeSureDartanalyzerRuns(usesFlutter),
                messages.runningDartanalyzerFailed(usesFlutter, e)));
          }
        }
        analyzeProcessStopwatch.stop();
      } else {
        analyzerItems = <CodeProblem>[];
      }
    }
    final pkgPlatformBlockerSuggestion =
        suggestions.firstWhere((s) => s.isError, orElse: () => null);
    var pkgPlatformConflict = pkgPlatformBlockerSuggestion?.title;

    final files = SplayTreeMap<String, DartFileSummary>();
    for (var dartFile in dartFiles) {
      final size = fileSize(pkgDir, dartFile);
      if (size == null) {
        log.warning('File deleted: $dartFile');
      }
      final isFormatted = unformattedFiles == null
          ? null
          : !unformattedFiles.contains(dartFile);
      final fileAnalyzerItems =
          analyzerItems?.where((item) => item.file == dartFile)?.toList();
      final codeErrors =
          fileAnalyzerItems?.where((cp) => cp.isError)?.toList() ?? const [];
      final platformBlockers =
          codeErrors.where((cp) => cp.isPlatformBlockingError).toList();
      var uri = toPackageUri(package, dartFile);
      final libPlatformBlocked = platformBlockers.isNotEmpty &&
          (reachableLibs == null || reachableLibs.contains(uri));
      var directLibs = allDirectLibs == null ? null : allDirectLibs[uri];
      var transitiveLibs =
          allTransitiveLibs == null ? null : allTransitiveLibs[uri];
      DartPlatform platform;
      if (libPlatformBlocked) {
        platform = DartPlatform.conflict(
            'Error(s) in $dartFile: ${platformBlockers.first.description}');
        pkgPlatformConflict ??= platform.reason;
      }
      if (transitiveLibs != null) {
        platform ??= classifyLibPlatform(transitiveLibs);
      }
      files[dartFile] = DartFileSummary(
        uri: uri,
        size: size,
        isFormatted: isFormatted,
        codeProblems: fileAnalyzerItems,
        directLibs: directLibs,
        transitiveLibs:
            options.verbosity == Verbosity.verbose ? transitiveLibs : null,
        platform: platform,
      );
    }

    final health = calcHealth(
      pubspec: pubspec,
      analyzeProcessFailed: pkgResolution == null || analyzerItems == null,
      formatProcessFailed: unformattedFiles == null,
      resolveProcessFailed: pkgResolution == null,
      analyzerItems: analyzerItems,
      dartFileSummaries: files.values,
    );

    DartPlatform platform;
    if (pkgPlatformConflict != null) {
      platform = DartPlatform.conflict(
          'Error(s) prevent platform classification:\n\n$pkgPlatformConflict');
    }
    platform ??= classifyPkgPlatform(pubspec, allTransitiveLibs);
    if (!platform.hasConflict && health.hasPlatformBlockingIssues) {
      platform = DartPlatform.conflict(
          'Low code quality prevents platform classification.');
    }

    var licenses = await detectLicensesInDir(pkgDir);
    licenses = await updateLicenseUrls(_urlChecker, pubspec.homepage, licenses);

    final maintenance = await detectMaintenance(
      options,
      _urlChecker,
      pkgDir,
      pubspec,
      pkgResolution?.getUnconstrainedDeps(onlyDirect: true),
      pkgPlatform: platform,
      dartdocSuccessful: dartdocSuccessful,
    );
    suggestions.sort();

    totalStopwatch.stop();
    final stats = Stats(
      analyzeProcessElapsed: analyzeProcessStopwatch.elapsedMilliseconds,
      formatProcessElapsed: formatProcessStopwatch.elapsedMilliseconds,
      resolveProcessElapsed: resolveProcessStopwatch.elapsedMilliseconds,
      totalElapsed: totalStopwatch.elapsedMilliseconds,
    );

    return Summary(
      runtimeInfo: _toolEnv.runtimeInfo,
      packageName: pubspec.name,
      packageVersion: pubspec.version,
      pubspec: options.verbosity == Verbosity.compact ? null : pubspec,
      pkgResolution:
          options.verbosity == Verbosity.compact ? null : pkgResolution,
      dartFiles: options.verbosity == Verbosity.compact ? null : files,
      platform: platform,
      licenses: licenses,
      health: health,
      maintenance: maintenance,
      suggestions: suggestions.isEmpty ? null : suggestions,
      stats: stats,
    );
  }

  Future<List<CodeProblem>> _pkgAnalyze(
      String pkgPath, bool usesFlutter) async {
    log.info('Analyzing package...');
    final dirs = await listFocusDirs(pkgPath);
    if (dirs.isEmpty) {
      return null;
    }
    final output = await _toolEnv.runAnalyzer(pkgPath, dirs, usesFlutter);
    final list = LineSplitter.split(output)
        .map((s) => parseCodeProblem(s, projectDir: pkgPath))
        .where((e) => e != null)
        .toSet()
        .toList();
    list.sort();
    return list;
  }

  Set<String> _reachableLibs(Map<String, List<String>> allTransitiveLibs) {
    final reached = <String>{};
    for (var lib in allTransitiveLibs.keys) {
      if (lib.startsWith('package:')) {
        final path = toRelativePath(lib);
        if (path.startsWith('lib/') && !path.startsWith('lib/src')) {
          reached.add(lib);
          reached.addAll(allTransitiveLibs[lib]);
        }
      }
    }
    return reached.intersection(allTransitiveLibs.keys.toSet());
  }
}
