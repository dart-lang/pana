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
import 'fitness.dart';
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

  PackageAnalyzer(this._toolEnv);

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
      log.info("Downloading package $package ${version ?? 'latest'}");
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
    log.info("SDK: ${_toolEnv.runtimeInfo.sdkVersion}");
    if (_toolEnv.pubCacheDir != null) {
      log.fine("Using .package-cache: ${_toolEnv.pubCacheDir}");
    }
    log.fine('Inspecting package at $pkgDir');
    final suggestions = <Suggestion>[];

    log.info('Counting files...');
    var dartFiles =
        await listFiles(pkgDir, endsWith: '.dart', deleteBadExtracted: true)
            .where((file) => file.startsWith('bin/') || file.startsWith('lib/'))
            .toList();

    log.info("Checking pubspec.yaml...");
    var pubspec = new Pubspec.parseFromDir(pkgDir);
    if (pubspec.hasUnknownSdks) {
      suggestions.add(new Suggestion.error(
          'Check SDKs in `pubspec.yaml`.',
          'We have found the following unknown SDKs in your `pubspec.yaml`:\n'
          '  `${pubspec.unknownSdks}`.\n\n'
          '`pana` does not recognizes them, please remove or report it to us.\n'));
    }

    final package = pubspec.name;
    log.info('Package: $package ${pubspec.version}');

    final usesFlutter = pubspec.usesFlutter;

    log.info("Checking formatting...");
    Set<String> unformattedFiles;
    try {
      unformattedFiles = new SplayTreeSet<String>.from(
          await _toolEnv.filesNeedingFormat(pkgDir));

      assert(unformattedFiles.every((f) => dartFiles.contains(f)),
          'dartfmt should only return Dart files');
    } catch (e, stack) {
      // FYI: seeing a lot of failures due to
      //   https://github.com/dart-lang/dart_style/issues/522
      log.severe("Failed dartfmt", e, stack);

      var errorMsg = LineSplitter.split(e.toString()).take(10).join('\n');
      suggestions.add(new Suggestion.error(
          messages.makeSureDartfmtRuns(usesFlutter),
          messages.runningDartfmtFailed(usesFlutter, errorMsg)));
    }

    log.info("Pub upgrade...");
    final upgrade = await _toolEnv.runUpgrade(pkgDir, usesFlutter);

    PkgResolution pkgResolution;
    if (upgrade.exitCode == 0) {
      try {
        pkgResolution = createPkgResolution(pubspec, upgrade.stdout as String,
            path: pkgDir);
      } catch (e, stack) {
        log.severe("Problem with pub upgrade", e, stack);
        //(TODO)kevmoo - should add a helper that handles logging exceptions
        //  and writing to issues in one go.

        final cmd =
            usesFlutter ? 'flutter packages pub upgrade' : 'pub upgrade';
        suggestions.add(new Suggestion.error(
            'Fix dependencies in `pubspec.yaml`.',
            'Running `$cmd` failed with the following output:\n\n'
            '```\n$e\n```\n'));
      }
    } else {
      String message;
      if (upgrade.exitCode > 0) {
        message = PubEntry
            .parse(upgrade.stderr as String)
            .where((e) => e.header == 'ERR')
            .join('\n');
      } else {
        message = LineSplitter.split(upgrade.stderr as String).first;
      }

      log.severe('`pub upgrade` failed.\n$message'.trim());

      final cmd = usesFlutter ? 'flutter packages pub upgrade' : 'pub upgrade';
      suggestions.add(new Suggestion.error(
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

    Set<CodeProblem> analyzerItems;

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
        log.severe("Could not create LibraryScanner", e, stack);
        suggestions.add(
            new Suggestion.bug('LibraryScanner creation failed.', e, stack));
      }

      if (libraryScanner != null) {
        try {
          log.info('Scanning direct dependencies...');
          allDirectLibs = await libraryScanner.scanDirectLibs();
        } catch (e, st) {
          log.severe('Error scanning direct libraries', e, st);
          suggestions.add(
              new Suggestion.bug('Error scanning direct libraries.', e, st));
        }
        try {
          log.info('Scanning transitive dependencies...');
          allTransitiveLibs = await libraryScanner.scanTransitiveLibs();
          reachableLibs = _reachableLibs(allTransitiveLibs);
        } catch (e, st) {
          log.severe('Error scanning transitive libraries', e, st);
          suggestions.add(new Suggestion.bug(
              'Error scanning transitive libraries.', e, st));
        }
      }

      if (dartFiles.isNotEmpty) {
        try {
          analyzerItems = await _pkgAnalyze(pkgDir, usesFlutter);
        } on ArgumentError catch (e) {
          if (e.toString().contains("No dart files found at: .")) {
            log.warning("No files to analyze...");
          } else {
            suggestions.add(new Suggestion.error(
                messages.makeSureDartanalyzerRuns(usesFlutter),
                messages.runningDartanalyzerFailed(usesFlutter, e)));
          }
        }
      }
    }
    final pkgPlatformBlockerSuggestion =
        suggestions.firstWhere((s) => s.isError, orElse: () => null);
    var pkgPlatformConflict = pkgPlatformBlockerSuggestion?.title;

    final dartFileSuggestions = <Suggestion>[];
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
      final isInLib = dartFile.startsWith('lib/');
      final fitnessResult = isInLib
          ? await calcFitness(pkgDir, pubspec, dartFile, isFormatted,
              fileAnalyzerItems, directLibs, platform)
          : null;
      files[dartFile] = new DartFileSummary(
        uri,
        size,
        isFormatted,
        fileAnalyzerItems,
        directLibs,
        options.verbosity == Verbosity.verbose ? transitiveLibs : null,
        platform,
        fitnessResult?.fitness,
        options.verbosity == Verbosity.verbose
            ? fitnessResult?.suggestions
            : null,
      );
      if (fitnessResult?.suggestions != null) {
        dartFileSuggestions.addAll(fitnessResult.suggestions);
      }
    }
    dartFileSuggestions.sort();

    DartPlatform platform;
    if (pkgPlatformConflict != null) {
      platform = new DartPlatform.conflict(
          'Error(s) prevent platform classification:\n\n$pkgPlatformConflict');
    }
    platform ??= classifyPkgPlatform(pubspec, allTransitiveLibs);

    var licenses = await detectLicensesInDir(pkgDir);
    licenses = await updateLicenseUrls(pubspec.homepage, licenses);
    final pkgFitness = calcPkgFitness(files.values);

    final maintenance = await detectMaintenance(
      pkgDir,
      pubspec,
      dartFileSuggestions,
      pkgResolution?.getUnconstrainedDeps(onlyDirect: true),
      pkgPlatform: platform,
      dartdocSuccessful: dartdocSuccessful,
    );
    suggestions.sort();

    return new Summary(
      _toolEnv.runtimeInfo,
      pubspec.name,
      pubspec.version,
      options.verbosity == Verbosity.compact ? null : pubspec,
      options.verbosity == Verbosity.compact ? null : pkgResolution,
      options.verbosity == Verbosity.compact ? null : files,
      platform,
      licenses,
      pkgFitness,
      maintenance,
      suggestions.isEmpty ? null : suggestions,
    );
  }

  Future<Set<CodeProblem>> _pkgAnalyze(String pkgPath, bool usesFlutter) async {
    log.info('Analyzing package...');
    final dirs = await listFocusDirs(pkgPath);
    if (dirs.isEmpty) {
      return null;
    }
    final output = await _toolEnv.runAnalyzer(pkgPath, dirs, usesFlutter);
    try {
      return new SplayTreeSet.from(LineSplitter
          .split(output)
          .map((s) => parseCodeProblem(s, projectDir: pkgPath))
          .where((e) => e != null));
    } on ArgumentError {
      // TODO: we should figure out a way to succeed here, right?
      // Or at least do partial results and not blow up
      log.severe("Bad input?");
      log.severe(output);
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
