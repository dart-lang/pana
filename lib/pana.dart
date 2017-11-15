// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'src/code_problem.dart';
import 'src/download_utils.dart';
import 'src/fitness.dart';
import 'src/library_scanner.dart';
import 'src/license.dart';
import 'src/logging.dart';
import 'src/maintenance.dart';
import 'src/pkg_resolution.dart';
import 'src/platform.dart';
import 'src/pubspec.dart';
import 'src/sdk_env.dart';
import 'src/summary.dart';
import 'src/utils.dart';
import 'src/version.dart';

export 'src/code_problem.dart';
export 'src/fitness.dart';
export 'src/license.dart';
export 'src/pkg_resolution.dart';
export 'src/platform.dart';
export 'src/pubspec.dart';
export 'src/sdk_env.dart';
export 'src/summary.dart';
export 'src/utils.dart';

class PackageAnalyzer {
  final DartSdk _dartSdk;
  final FlutterSdk _flutterSdk;
  PubEnvironment _pubEnv;

  PackageAnalyzer({String sdkDir, String flutterDir, String pubCacheDir})
      : _dartSdk = new DartSdk(sdkDir: sdkDir),
        _flutterSdk = new FlutterSdk(sdkDir: flutterDir) {
    _pubEnv = new PubEnvironment(
        dartSdk: _dartSdk, flutterSdk: _flutterSdk, pubCacheDir: pubCacheDir);
  }

  Future<Summary> inspectPackage(
    String package, {
    String version,
    bool keepTransitiveLibs: false,
  }) async {
    log.info("Downloading package $package ${version ?? 'latest'}");
    var packageDir;
    Directory tempDir;
    if (version != null) {
      tempDir = await downloadPackage(package, version);
      packageDir = tempDir?.path;
    }
    if (packageDir == null) {
      var pkgInfo = await _pubEnv.getLocation(package, version: version);
      packageDir = pkgInfo.location;
    }
    try {
      return await _inspect(packageDir, keepTransitiveLibs);
    } finally {
      await tempDir?.delete(recursive: true);
    }
  }

  Future<Summary> inspectDir(String packageDir,
      {bool keepTransitiveLibs: false}) {
    return _inspect(packageDir, keepTransitiveLibs);
  }

  Future<Summary> _inspect(String pkgDir, bool keepTransitiveLibs) async {
    log.info("SDK: ${_dartSdk.version}");
    if (_pubEnv.pubCacheDir != null) {
      log.fine("Using .package-cache: ${_pubEnv.pubCacheDir}");
    }
    log.fine('Inspecting package at $pkgDir');
    final suggestions = <Suggestion>[];

    log.info('Counting files...');
    var dartFiles =
        await listFiles(pkgDir, endsWith: '.dart', deleteBadExtracted: true)
            .where((file) => file.startsWith('bin/') || file.startsWith('lib/'))
            .toList();

    log.info("Checking formatting...");
    Set<String> unformattedFiles;
    try {
      unformattedFiles = new SplayTreeSet<String>.from(
          await _dartSdk.filesNeedingFormat(pkgDir));

      assert(unformattedFiles.every((f) => dartFiles.contains(f)),
          'dartfmt should only return Dart files');
    } catch (e, stack) {
      // FYI: seeing a lot of failures due to
      //   https://github.com/dart-lang/dart_style/issues/522
      log.severe("Failed dartfmt", e, stack);

      var errorMsg = LineSplitter.split(e.toString()).take(10).join('\n');
      suggestions.add(new Suggestion.error(
          'Make sure `dartfmt` runs.',
          'Running `dartfmt -n .` failed with the following output:\n\n'
          '```\n$errorMsg\n```\n'));
    }

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

    log.info("Pub upgrade...");
    await _pubEnv.removeDevDependencies(pkgDir);
    final isFlutter = pubspec.isFlutter;
    var upgrade = await _pubEnv.runUpgrade(pkgDir, isFlutter);

    PkgResolution pkgResolution;
    if (upgrade.exitCode == 0) {
      try {
        pkgResolution =
            PkgResolution.create(pubspec, upgrade.stdout, path: pkgDir);
      } catch (e, stack) {
        log.severe("Problem with pub upgrade", e, stack);
        //(TODO)kevmoo - should add a helper that handles logging exceptions
        //  and writing to issues in one go.

        final cmd = isFlutter ? 'flutter packages pub upgrade' : 'pub upgrade';
        suggestions.add(new Suggestion.error(
            'Fix dependencies in `pubspec.yaml`.',
            'Running `$cmd` failed with the following output:\n\n'
            '```\n$e\n```\n'));
      }
    } else {
      String message;
      if (upgrade.exitCode > 0) {
        message = PubEntry
            .parse(upgrade.stderr)
            .where((e) => e.header == 'ERR')
            .join('\n');
      } else {
        message = LineSplitter.split(upgrade.stderr).first;
      }

      log.severe('`pub upgrade` failed.\n$message'.trim());

      final cmd = isFlutter ? 'flutter packages pub upgrade' : 'pub upgrade';
      suggestions.add(new Suggestion.error(
          'Fix dependencies in `pubspec.yaml`.',
          message.isEmpty
              ? 'Running `$cmd` failed.'
              : 'Running `$cmd` failed with the following output:\n\n'
              '```\n$message\n```\n'));
    }

    Map<String, List<String>> allDirectLibs;
    Map<String, List<String>> allTransitiveLibs;

    LibraryScanner libraryScanner;

    Set<CodeProblem> analyzerItems;

    if (pkgResolution != null) {
      try {
        var overrides = [
          new LibraryOverride.webSafeIO('package:http/http.dart'),
          new LibraryOverride.webSafeIO('package:http/browser_client.dart'),
          new LibraryOverride.webSafeIO(
              'package:package_resolver/package_resolver.dart'),
        ];

        libraryScanner = new LibraryScanner(_pubEnv, pkgDir, isFlutter,
            overrides: overrides);
        assert(libraryScanner.packageName == package);
      } on StateError catch (e, stack) {
        log.severe("Could not create LibraryScanner", e, stack);
        suggestions.add(new Suggestion.error(
            'Check your code structure and library use.',
            'Our library analysis failed with the following error:\n\n$e'));
      }

      if (libraryScanner != null) {
        try {
          log.info('Scanning direct dependencies...');
          allDirectLibs = await libraryScanner.scanDirectLibs();
        } catch (e, st) {
          log.severe('Error scanning direct librariers', e, st);
          suggestions.add(new Suggestion.error(
              'Check your code structure and library use.',
              'Our library analysis failed with the following error:\n\n$e'));
        }
        try {
          log.info('Scanning transitive dependencies...');
          allTransitiveLibs = await libraryScanner.scanTransitiveLibs();
        } catch (e, st) {
          log.severe('Error scanning transitive librariers', e, st);
          suggestions.add(new Suggestion.error(
              'Check your code structure and library use.',
              'Our library analysis failed with the following error:\n\n$e'));
        }
        libraryScanner.clearCaches();
      }

      if (dartFiles.isNotEmpty) {
        try {
          analyzerItems = await _pkgAnalyze(pkgDir);
        } on ArgumentError catch (e) {
          if (e.toString().contains("No dart files found at: .")) {
            log.warning("No files to analyze...");
          } else {
            suggestions.add(new Suggestion.error(
                'Make sure `dartanalyzer` runs.',
                'Running `dartanalyzer .` failed with the following output:\n\n'
                '```\n$e\n```\n'));
          }
        }
      }
    }

    final dartFileSuggestions = <Suggestion>[];
    Map<String, DartFileSummary> files = new SplayTreeMap();
    for (var dartFile in dartFiles) {
      var size = await fileSize(pkgDir, dartFile);
      final isFormatted = unformattedFiles == null
          ? null
          : !unformattedFiles.contains(dartFile);
      final fileAnalyzerItems =
          analyzerItems?.where((item) => item.file == dartFile)?.toList();
      var uri = toPackageUri(package, dartFile);
      var directLibs = allDirectLibs == null ? null : allDirectLibs[uri];
      var transitiveLibs =
          allTransitiveLibs == null ? null : allTransitiveLibs[uri];
      var platform;
      final firstError =
          fileAnalyzerItems?.firstWhere((cp) => cp.isError, orElse: () => null);
      if (firstError != null) {
        platform = new DartPlatform.conflict(
            'Error(s) in ${dartFile}: ${firstError.description}');
      }
      if (transitiveLibs != null) {
        platform ??= classifyLibPlatform(transitiveLibs);
      }
      final isInLib = dartFile.startsWith('lib/');
      final fitness = isInLib
          ? await calcFitness(pkgDir, dartFile, isFormatted, fileAnalyzerItems,
              directLibs, platform)
          : null;
      files[dartFile] = new DartFileSummary(
        uri,
        size,
        isFormatted,
        fileAnalyzerItems,
        directLibs,
        keepTransitiveLibs ? transitiveLibs : null,
        platform,
        fitness,
      );
      if (isInLib && firstError != null) {
        dartFileSuggestions.add(new Suggestion.error(
          'Fix `${dartFile}`.',
          'Strong-mode analysis of `${dartFile}` failed with the following error:\n\n'
              'line: ${firstError.line} col: ${firstError.col}  \n'
              '${firstError.description}\n',
          file: dartFile,
        ));
      }
    }
    if (dartFileSuggestions.length < 3) {
      suggestions.addAll(dartFileSuggestions);
    } else {
      suggestions.addAll(dartFileSuggestions.take(2));
      // Fold the rest of the files into a single suggestions.
      final items =
          dartFileSuggestions.skip(2).map((s) => '- ${s.file}\n').toList();
      suggestions.add(new Suggestion.error(
          'Fix further ${items.length} Dart files.',
          'Similar analysis of the following files failed:\n\n'
          '${items.join()}\n'));
    }

    Map<String, Object> flutterVersion;
    if (isFlutter) {
      flutterVersion = await _flutterSdk.getVersion();
    }

    DartPlatform platform;
    if (suggestions.where((s) => s.isError).isNotEmpty) {
      platform =
          new DartPlatform.conflict('Errors prevent platform classification.');
    } else {
      final dfs = files.values.firstWhere(
          (dfs) => dfs.isPublicApi && dfs.hasCodeError,
          orElse: () => null);
      if (dfs != null) {
        platform = new DartPlatform.conflict(
            'Error(s) in ${dfs.path}: ${dfs.firstCodeError.description}');
      }
    }
    platform ??= classifyPkgPlatform(pubspec, allTransitiveLibs);

    var licenses = await detectLicensesInDir(pkgDir);
    licenses = await updateLicenseUrls(pubspec.homepage, licenses);
    final pkgFitness = calcPkgFitness(pubspec, platform, files.values);

    final maintenance = await detectMaintenance(
        pkgDir, pubspec.version?.toString(), suggestions);
    suggestions.sort();

    return new Summary(
      panaPkgVersion,
      _dartSdk.version,
      pubspec.name,
      pubspec.version,
      pubspec,
      pkgResolution,
      files,
      platform,
      licenses,
      pkgFitness,
      maintenance,
      suggestions.isEmpty ? null : suggestions,
      flutterVersion: flutterVersion,
    );
  }

  Future<Set<CodeProblem>> _pkgAnalyze(String pkgPath) async {
    log.info('Analyzing package...');
    final dirs = await listFocusDirs(pkgPath);
    if (dirs.isEmpty) {
      return null;
    }
    final proc = await _dartSdk.runAnalyzer(pkgPath, dirs);

    String output = proc.stderr;
    if ('\n$output'.contains('\nUnhandled exception:\n')) {
      log.severe("Bad input?");
      log.severe(output);
      var errorMessage =
          '\n$output'.split('\nUnhandled exception:\n')[1].split('\n').first;
      throw new ArgumentError('dartanalyzer exception: $errorMessage');
    }

    try {
      return new SplayTreeSet.from(LineSplitter
          .split(output)
          .map((s) => CodeProblem.parse(s, projectDir: pkgPath))
          .where((e) => e != null));
    } on ArgumentError {
      // TODO: we should figure out a way to succeed here, right?
      // Or at least do partial results and not blow up
      log.severe("Bad input?");
      log.severe(output);
      rethrow;
    }
  }
}
