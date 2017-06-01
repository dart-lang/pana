// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

import 'src/analyzer_output.dart';
import 'src/logging.dart';
import 'src/pub_summary.dart';
import 'src/sdk_env.dart';
import 'src/summary.dart';
import 'src/utils.dart';

export 'src/pub_summary.dart';
export 'src/summary.dart';
export 'src/utils.dart';

class PackageAnalyzer {
  final DartSdk _dartSdk;
  PubEnvironment _pubEnv;

  PackageAnalyzer({String sdkDir, String pubCacheDir})
      : _dartSdk = new DartSdk(sdkDir: sdkDir) {
    _pubEnv = new PubEnvironment(dartSdk: _dartSdk, pubCacheDir: pubCacheDir);
  }

  Future<Summary> inspectPackage(String package, {String version}) async {
    var sdkVersion = _dartSdk.version;
    log.info("SDK: $sdkVersion");

    log.info("Package: $package");

    Version ver;
    if (version != null) {
      ver = new Version.parse(version);
      log.info("Version: $ver");
    }

    if (_pubEnv.pubCacheDir != null) {
      log.info("Using .package-cache: ${_pubEnv.pubCacheDir}");
    }

    log.info("Downloading package...");
    PackageLocation pkgInfo =
        await _pubEnv.getLocation(package, version: ver?.toString());
    String pkgDir = pkgInfo.location;
    log.info("Package at $pkgDir");

    log.info('Counting files...');
    var dartFiles =
        await listFiles(pkgDir, endsWith: '.dart');

    log.info("Checking formatting...");
    var unformattedFiles = new SplayTreeSet<String>.from(
        await _dartSdk.filesNeedingFormat(pkgDir));

    log.info("Pub upgrade...");
    ProcessResult upgrade = await _pubEnv.runUpgrade(pkgDir);
    var summary = PubSummary.create(
        upgrade.exitCode, upgrade.stdout, upgrade.stderr, pkgDir);
    log.info("Package version: ${summary.pkgVersion}");

    Set<AnalyzerOutput> analyzerItems;
    try {
      analyzerItems = await _pkgAnalyze(pkgDir);
    } on ArgumentError catch (e) {
      if (e.toString().contains("No dart files found at: .")) {
        log.warning("No files to analyze...");
        analyzerItems = new Set<AnalyzerOutput>();
      } else {
        rethrow;
      }
    }

    return new Summary(sdkVersion, package, new Version.parse(pkgInfo.version),
        dartFiles, summary, analyzerItems, unformattedFiles);
  }

  Future<Set<AnalyzerOutput>> _pkgAnalyze(String pkgPath) async {
    log.info('Running `dartanalyzer`...');
    var proc = await _dartSdk.runAnalyzer(pkgPath);

    try {
      return new SplayTreeSet.from(LineSplitter
          .split(proc.stderr)
          .map((s) => AnalyzerOutput.parse(s, projectDir: pkgPath))
          .where((e) => e != null));
    } on ArgumentError {
      // TODO: we should figure out a way to succeed here, right?
      // Or at least do partial results and not blow up
      log.severe("Bad input?");
      log.severe(proc.stderr);
      rethrow;
    }
  }
}
