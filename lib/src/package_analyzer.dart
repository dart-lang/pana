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
import 'pkg_resolution.dart';
import 'platform.dart';
import 'pubspec.dart';
import 'sdk_env.dart';
import 'summary.dart';
import 'utils.dart';
import 'version.dart';

class PackageAnalyzer {
  final DartSdk _dartSdk;
  final FlutterSdk _flutterSdk;
  final PubEnvironment _pubEnv;

  PackageAnalyzer._(this._dartSdk, this._flutterSdk, this._pubEnv);

  factory PackageAnalyzer(DartSdk dartSdk,
      {String flutterDir, String pubCacheDir}) {
    var flutterSdk = new FlutterSdk(sdkDir: flutterDir);

    var pubEnv = new PubEnvironment(dartSdk,
        flutterSdk: flutterSdk, pubCacheDir: pubCacheDir);

    return new PackageAnalyzer._(dartSdk, flutterSdk, pubEnv);
  }

  static Future<PackageAnalyzer> create(
          {String sdkDir, String flutterDir, String pubCacheDir}) async =>
      new PackageAnalyzer(await DartSdk.create(sdkDir: sdkDir),
          flutterDir: flutterDir, pubCacheDir: pubCacheDir);

  Future<Summary> inspectPackage(
    String package, {
    String version,
    bool keepTransitiveLibs: false,
    Logger logger,
    bool deleteTemporaryDirectory: true,
    String pubHostedUrl,
  }) async {
    deleteTemporaryDirectory ??= true;
    return withLogger(() async {
      log.info("Downloading package $package ${version ?? 'latest'}");
      String packageDir;
      Directory tempDir;
      if (version != null) {
        tempDir =
            await downloadPackage(package, version, pubHostedUrl: pubHostedUrl);
        packageDir = tempDir?.path;
      }
      if (packageDir == null) {
        var pkgInfo = await _pubEnv.getLocation(package, version: version);
        packageDir = pkgInfo.location;
      }
      try {
        return await _inspect(packageDir, keepTransitiveLibs);
      } finally {
        if (deleteTemporaryDirectory) {
          await tempDir?.delete(recursive: true);
        } else {
          log.warning(
              'Temporary directory was not deleted: `${tempDir.path}`.');
        }
      }
    }, logger: logger);
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
        } catch (e, st) {
          log.severe('Error scanning transitive libraries', e, st);
          suggestions.add(new Suggestion.bug(
              'Error scanning transitive libraries.', e, st));
        }
        libraryScanner.clearCaches();
      }

      if (dartFiles.isNotEmpty) {
        try {
          analyzerItems = await _pkgAnalyze(pkgDir, isFlutter);
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
    var pkgPlatformBlocked = suggestions.where((s) => s.isError).isNotEmpty;

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
      final libPlatformBlocked = platformBlockers.isNotEmpty;
      pkgPlatformBlocked = pkgPlatformBlocked || libPlatformBlocked;
      var uri = toPackageUri(package, dartFile);
      var directLibs = allDirectLibs == null ? null : allDirectLibs[uri];
      var transitiveLibs =
          allTransitiveLibs == null ? null : allTransitiveLibs[uri];
      DartPlatform platform;
      final firstError = codeErrors.isEmpty ? null : codeErrors.first;
      if (libPlatformBlocked) {
        platform = new DartPlatform.conflict(
            'Error(s) in ${dartFile}: ${platformBlockers.first.description}');
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
    if (pkgPlatformBlocked) {
      platform = new DartPlatform.conflict(
          'Error(s) prevent platform classification.');
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

    final maintenance =
        await detectMaintenance(pkgDir, pubspec.version, suggestions);
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

  Future<Set<CodeProblem>> _pkgAnalyze(String pkgPath, bool isFlutter) async {
    log.info('Analyzing package...');
    final dirs = await listFocusDirs(pkgPath);
    if (dirs.isEmpty) {
      return null;
    }
    final proc = await _dartSdk.runAnalyzer(pkgPath, dirs, isFlutter);

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
