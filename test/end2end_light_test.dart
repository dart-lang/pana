// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'env_utils.dart';

void main() {
  void verifyPackage(String package) {
    group('end2end light: $package', () {
      late TestEnv testEnv;

      setUpAll(() async {
        testEnv = await TestEnv.createTemp();
      });

      tearDownAll(() async {
        await testEnv.close();
      });

      test('analysis', () async {
        final summary = await testEnv.analyzer.inspectPackage(package);
        expect(summary.report, isNotNull);
        expect(summary.allDependencies!, isNotEmpty);
        expect(summary.tags!, isNotEmpty);
        expect(summary.tags, contains('is:dart3-compatible'));
        expect(
          summary.report!.grantedPoints,
          greaterThanOrEqualTo(summary.report!.maxPoints - 20),
        );
      }, timeout: const Timeout.factor(4));
    });
  }

  // generic, cross-platform package
  verifyPackage('async');

  // flutter-only package
  verifyPackage('url_launcher');
}
