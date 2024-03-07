// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/pana.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  void verifyPackage(String package) {
    group('end2end light: $package', () {
      late String tempDir;
      late PackageAnalyzer analyzer;

      setUpAll(() async {
        tempDir = Directory.systemTemp
            .createTempSync('pana-test')
            .resolveSymbolicLinksSync();
        final pubCacheDir = p.join(tempDir, 'pub-cache');
        final dartConfigDir = p.join(tempDir, 'config', 'dart');
        final flutterConfigDir = p.join(tempDir, 'config', 'flutter');
        Directory(pubCacheDir).createSync();
        Directory(dartConfigDir).createSync(recursive: true);
        Directory(flutterConfigDir).createSync(recursive: true);
        analyzer = PackageAnalyzer(await ToolEnvironment.create(
          dartSdkConfig: SdkConfig(configHomePath: dartConfigDir),
          flutterSdkConfig: SdkConfig(configHomePath: flutterConfigDir),
          pubCacheDir: pubCacheDir,
          dartdocVersion: 'any',
        ));
      });

      tearDownAll(() async {
        Directory(tempDir).deleteSync(recursive: true);
      });

      test('analysis', () async {
        final summary = await analyzer.inspectPackage(package);
        expect(summary.report, isNotNull);
        expect(summary.allDependencies!, isNotEmpty);
        expect(summary.tags!, isNotEmpty);
        expect(summary.tags, contains('is:dart3-compatible'));
        expect(summary.report!.grantedPoints,
            greaterThanOrEqualTo(summary.report!.maxPoints - 20));
      }, timeout: const Timeout.factor(4));
    });
  }

  // generic, cross-platform package
  verifyPackage('async');

  // flutter-only package
  verifyPackage('url_launcher');
}
