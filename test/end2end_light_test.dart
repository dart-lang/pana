// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/pana.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String tempDir;
  late PackageAnalyzer analyzer;

  setUpAll(() async {
    tempDir = Directory.systemTemp
        .createTempSync('pana-test')
        .resolveSymbolicLinksSync();
    final pubCacheDir = p.join(tempDir, 'pub-cache');
    Directory(pubCacheDir).createSync();
    analyzer = await PackageAnalyzer.create(pubCacheDir: pubCacheDir);
  });

  tearDownAll(() async {
    Directory(tempDir).deleteSync(recursive: true);
  });

  void verifyPackage(String package) {
    test('end2end light: $package', () async {
      final summary = await analyzer.inspectPackage(
        package,
        options: InspectOptions(
          futureSdkTag: 'is:future-compatible',
        ),
      );
      expect(summary.report, isNotNull);
      expect(summary.allDependencies!, isNotEmpty);
      expect(summary.tags!, isNotEmpty);
      expect(summary.tags, contains('is:future-compatible'));
      expect(summary.report!.grantedPoints,
          greaterThanOrEqualTo(summary.report!.maxPoints - 20));
    }, timeout: const Timeout.factor(2));
  }

  // generic, cross-platform package
  verifyPackage('async');

  // flutter-only package
  verifyPackage('url_launcher');
}
