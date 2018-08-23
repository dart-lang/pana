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

  InspectOptions({
    this.verbosity: Verbosity.normal,
    this.deleteTemporaryDirectory: true,
    this.pubHostedUrl,
    this.dartdocOutputDir,
    this.dartdocRetry: 0,
    this.dartdocTimeout,
  });
}

class PackageAnalyzer {
  final ToolEnvironment _toolEnv;
  final UrlChecker _urlChecker;

  PackageAnalyzer(this._toolEnv, {UrlChecker urlChecker})
      : _urlChecker = urlChecker ?? new UrlChecker();

  static Future<PackageAnalyzer> create(
      {String sdkDir, String flutterDir, String pubCacheDir}) async {
    return new PackageAnalyzer(await ToolEnvironment.create(
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
    options ??= new InspectOptions();
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
    options ??= new InspectOptions();
    return _inspect(packageDir, options);
  }

  Future<Summary> _inspect(String pkgDir, InspectOptions options) async {
    final suggestions = <Suggestion>[];

    var dartFiles =
        await listFiles(pkgDir, endsWith: '.dart', deleteBadExtracted: true)
            .where((file) => file.startsWith('bin/') || file.startsWith('lib/'))
            .toList();

    log.info('Parsing pubspec.yaml...');
    var pubspec = new Pubspec.parseFromDir(pkgDir);
    if (pubspec.hasUnknownSdks) {
      suggestions.add(new Suggestion.error(
          SuggestionCode.pubspecSdkUnknown,
          'Check SDKs in `pubspec.yaml`.',
          'We have found the following unknown SDKs in your `pubspec.yaml`:\n'
          '  `${pubspec.unknownSdks}`.\n\n'
          '`pana` does not recognizes them, please remove or report it to us.\n'));
    }

    final package = pubspec.name;
    final usesFlutter = pubspec.usesFlutter;

    Set<String> unformattedFiles;
    try {
      unformattedFiles = new SplayTreeSet<String>.from(
          await _toolEnv.filesNeedingFormat(pkgDir, usesFlutter));

      assert(unformattedFiles.every((f) => dartFiles.contains(f)),
          'dartfmt should only return Dart files');
    } catch (e, stack) {
      final errorMsg = LineSplitter.split(e.toString()).take(10).join('\n');
      final isUserProblem = errorMsg
          .contains('Could not format because the source could not be parsed');
      if (!isUserProblem) {
        log.severe('`dartfmt` failed.\n$errorMsg', e, stack);
      }

      suggestions.add(new Suggestion.error(
          SuggestionCode.dartfmtAborted,
          messages.makeSureDartfmtRuns(usesFlutter),
          messages.runningDartfmtFailed(usesFlutter, errorMsg)));
    }

    final upgrade = await _toolEnv.runUpgrade(pkgDir, usesFlutter);

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
        suggestions.add(new Suggestion.error(
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

      final isUserProblem = message.contains('version solving failed') ||
          message.contains('Git error.');
      if (!isUserProblem) {
        log.severe('`pub upgrade` failed.\n$message'.trim());
      }

      final cmd = usesFlutter ? 'flutter packages pub upgrade' : 'pub upgrade';
      suggestions.add(new Suggestion.error(
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
          new LibraryOverride.webSafeIO('package:http/http.dart'),
          new LibraryOverride.webSafeIO('package:http/browser_client.dart'),
          new LibraryOverride.webSafeIO(
              'package:package_resolver/package_resolver.dart'),
        ];

        libraryScanner = new LibraryScanner(_toolEnv.dartSdkDir, pkgDir,
            overrides: overrides);
        assert(libraryScanner.packageName == package);
      } catch (e, stack) {
        log.severe('Could not create LibraryScanner', e, stack);
        suggestions.add(new Suggestion.bug(
            SuggestionCode.exceptionInLibraryScanner,
            'LibraryScanner creation failed.',
            e,
            stack));
      }

      if (libraryScanner != null) {
        try {
          log.info('Scanning direct dependencies...');
          allDirectLibs = await libraryScanner.scanDirectLibs();
        } catch (e, st) {
          log.severe('Error scanning direct libraries', e, st);
          suggestions.add(new Suggestion.bug(
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
          suggestions.add(new Suggestion.bug(
              SuggestionCode.exceptionInLibraryScanner,
              'Error scanning transitive libraries.',
              e,
              st));
        }
      }

      if (dartFiles.isNotEmpty) {
        try {
          analyzerItems = await _pkgAnalyze(pkgDir, usesFlutter);
        } on ArgumentError catch (e) {
          if (e.toString().contains('No dart files found at: .')) {
            log.warning('`dartanalyzer` found no files to analyze.');
          } else {
            suggestions.add(new Suggestion.error(
                SuggestionCode.dartanalyzerAborted,
                messages.makeSureDartanalyzerRuns(usesFlutter),
                messages.runningDartanalyzerFailed(usesFlutter, e)));
          }
        }
      }
    }
    final pkgPlatformBlockerSuggestion =
        suggestions.firstWhere((s) => s.isError, orElse: () => null);
    var pkgPlatformConflict = pkgPlatformBlockerSuggestion?.title;

    final files = new SplayTreeMap<String, DartFileSummary>();
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
        platform = new DartPlatform.conflict(
            'Error(s) in ${dartFile}: ${platformBlockers.first.description}');
        pkgPlatformConflict ??= platform.reason;
      }
      if (transitiveLibs != null) {
        platform ??= classifyLibPlatform(transitiveLibs);
      }
      files[dartFile] = new DartFileSummary(
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

    final health = calcHealth(pubspec, analyzerItems, files.values);

    DartPlatform platform;
    if (pkgPlatformConflict != null) {
      platform = new DartPlatform.conflict(
          'Error(s) prevent platform classification:\n\n$pkgPlatformConflict');
    }
    platform ??= classifyPkgPlatform(pubspec, allTransitiveLibs);
    if (!platform.hasConflict && health.healthScore < 0.33) {
      platform = new DartPlatform.conflict(
          'Low code quality prevents platform classification.');
    }

    var licenses = await detectLicensesInDir(pkgDir);
    licenses = await updateLicenseUrls(_urlChecker, pubspec.homepage, licenses);

    final maintenance = await detectMaintenance(
      _urlChecker,
      pkgDir,
      pubspec,
      pkgResolution?.getUnconstrainedDeps(onlyDirect: true),
      pkgPlatform: platform,
      dartdocSuccessful: dartdocSuccessful,
    );
    suggestions.sort();

    return new Summary(
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
    try {
      final list = LineSplitter.split(output)
          .map((s) => parseCodeProblem(s, projectDir: pkgPath))
          .where((e) => e != null)
          .toSet()
          .toList();
      list.sort();
      return list;
    } on ArgumentError {
      // TODO: we should figure out a way to succeed here, right?
      // Or at least do partial results and not blow up
      log.severe('Bad input?\n\n$output');
      rethrow;
    }
  }

  Set<String> _reachableLibs(Map<String, List<String>> allTransitiveLibs) {
    final reached = new Set<String>();
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
