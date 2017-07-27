// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';

import 'src/analyzer_output.dart';
import 'src/library_scanner.dart';
import 'src/license.dart';
import 'src/logging.dart';
import 'src/platform.dart';
import 'src/pub_summary.dart';
import 'src/pubspec.dart';
import 'src/sdk_env.dart';
import 'src/summary.dart';
import 'src/utils.dart';
import 'src/version.dart';

export 'src/analyzer_output.dart';
export 'src/license.dart';
export 'src/platform.dart';
export 'src/pub_summary.dart';
export 'src/pubspec.dart';
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

  Future<Summary> inspectPackage(String package,
      {String version, bool keepTransitiveLibs: false}) async {
    var issues = <AnalyzerIssue>[];
    var sdkVersion = _dartSdk.version;
    log.info("SDK: $sdkVersion");

    log.info("Package: $package");

    Version ver;
    if (version != null) {
      ver = new Version.parse(version);
      log.info("Version: $ver");
    }

    if (_pubEnv.pubCacheDir != null) {
      log.fine("Using .package-cache: ${_pubEnv.pubCacheDir}");
    }

    log.info("Downloading package...");
    var pkgInfo = await _pubEnv.getLocation(package, version: ver?.toString());
    var pkgDir = pkgInfo.location;
    log.fine("Package at $pkgDir");

    log.info('Counting files...');
    var dartFiles = await listFiles(pkgDir, endsWith: '.dart');

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

      issues.add(new AnalyzerIssue(
          AnalyzerScopes.dartfmt, "Problem formatting package:\n$errorMsg"));
    }

    log.info("Checking pubspec.yaml...");
    var pubspec = new Pubspec.parseFromDir(pkgDir);
    if (pubspec.hasUnknownSdks) {
      issues.add(new AnalyzerIssue(AnalyzerScopes.pubspec,
          'Unknown SDKs: ${pubspec.unknownSdks}', 'unknown-sdks'));
    }

    log.info("Pub upgrade...");
    var isFlutter = pubspec.dependsOnFlutterSdk;
    var upgrade = await _pubEnv.runUpgrade(pkgDir, isFlutter);

    PubSummary summary;
    if (upgrade.exitCode == 0) {
      try {
        summary = PubSummary.create(upgrade.stdout, path: pkgDir);
      } catch (e, stack) {
        log.severe("Problem summarizing package", e, stack);
        //(TODO)kevmoo - should add a helper that handles logging exceptions
        //  and writing to issues in one go.
        issues.add(new AnalyzerIssue(
            AnalyzerScopes.pubspec, "Problem summarizing package: $e"));
      }
      if (summary != null) {
        log.info("Package version: ${summary.pkgVersion}");
      }
    } else {
      String message;
      if (upgrade.exitCode > 0) {
        message = PubEntry
            .parse(upgrade.stderr)
            .where((e) => e.header == 'ERR')
            .toList()
            .join('\n');
      } else {
        message = LineSplitter.split(upgrade.stderr).first;
      }

      if (message.isEmpty) {
        message = null;
      }

      message =
          ["`pub upgrade` failed.", message].where((m) => m != null).join('\n');

      log.severe(message);
      issues.add(new AnalyzerIssue(
          AnalyzerScopes.pubUpgrade, message, upgrade.exitCode));
    }

    Map<String, List<String>> allDirectLibs;
    Map<String, List<String>> allTransitiveLibs;

    LibraryScanner libraryScanner;

    Set<AnalyzerOutput> analyzerItems;

    if (summary != null) {
      try {
        var overrides = {
          'package:http/http.dart': ['dart:web_safe_io'],
          'package:http/browser_client.dart': ['dart:html', 'dart:web_safe_io'],
          'package:package_resolver/package_resolver.dart': ['dart:web_safe_io']
        };

        libraryScanner =
            new LibraryScanner(pkgDir, isFlutter, overrides: overrides);
        assert(libraryScanner.packageName == package);
      } on StateError catch (e, stack) {
        log.severe("Could not create LibraryScanner", e, stack);
        issues.add(new AnalyzerIssue(
            AnalyzerScopes.libraryScanner, e.toString(), 'init'));
      }

      if (libraryScanner != null) {
        try {
          log.info('Scanning direct dependencies...');
          allDirectLibs = await libraryScanner.scanDirectLibs();
        } catch (e, st) {
          log.severe('Error scanning direct librariers', e, st);
          issues.add(new AnalyzerIssue(
              AnalyzerScopes.libraryScanner, e.toString(), 'direct'));
        }
        try {
          log.info('Scanning transitive dependencies...');
          allTransitiveLibs = await libraryScanner.scanTransitiveLibs();
        } catch (e, st) {
          log.severe('Error scanning transitive librariers', e, st);
          issues.add(new AnalyzerIssue(
              AnalyzerScopes.libraryScanner, e.toString(), 'transient'));
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
            issues.add(
                new AnalyzerIssue(AnalyzerScopes.dartAnalyzer, e.toString()));
          }
        }
      }
    }

    Map<String, DartFileSummary> files = new SplayTreeMap();
    for (var dartFile in dartFiles) {
      var size = await fileSize(pkgDir, dartFile);
      var uri = toPackageUri(package, dartFile);
      var directLibs = allDirectLibs == null ? null : allDirectLibs[uri];
      var transitiveLibs =
          allTransitiveLibs == null ? null : allTransitiveLibs[uri];
      var platform =
          transitiveLibs == null ? null : classifyPlatform(transitiveLibs);
      files[dartFile] = new DartFileSummary(
        uri,
        size,
        unformattedFiles == null ? null : !unformattedFiles.contains(dartFile),
        analyzerItems?.where((item) => item.file == dartFile)?.toList(),
        directLibs,
        keepTransitiveLibs ? transitiveLibs : null,
        platform,
      );
    }

    Map<String, Object> flutterVersion;
    if (isFlutter) {
      flutterVersion = await _flutterSdk.getVersion();
    }

    var license = await detectLicenseInDir(pkgDir);

    return new Summary(panaPkgVersion, sdkVersion, package,
        new Version.parse(pkgInfo.version), summary, files, issues, license,
        flutterVersion: flutterVersion);
  }

  Future<Set<AnalyzerOutput>> _pkgAnalyze(String pkgPath) async {
    log.info('Analyzing package...');
    var proc = await _dartSdk.runAnalyzer(pkgPath);

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
          .map((s) => AnalyzerOutput.parse(s, projectDir: pkgPath))
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
