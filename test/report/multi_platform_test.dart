// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/multi_platform.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../package_descriptor.dart';

void main() {
  group('Kotlin built-in detection in report', () {
    test('Shows warning if legacy Kotlin is used', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps(
          'my_package',
          sdkConstraint: '^3.0.0',
          pubspecExtras: {
            'flutter': {
              'plugin': {
                'platforms': {
                  'android': <String, dynamic>{'pluginClass': 'MyPlugin'},
                },
              },
            },
          },
          extraFiles: [
            d.dir('android', [
              d.file('build.gradle', '''
                apply plugin: 'com.android.library'
                apply plugin: 'kotlin-android'
              '''),
            ]),
          ],
        ),
      ]);
      await descriptor.create();

      final reportSection = await multiPlatform(
        PackageContext(
          sharedContext: SharedAnalysisContext(
            toolEnvironment: await ToolEnvironment.create(),
          ),
          packageDir: '${descriptor.io.path}/my_package',
        ),
      );

      expect(
        reportSection.grantedPoints,
        20,
      ); // Score should not be affected yet
      expect(
        reportSection.summary,
        contains(
          'Legacy Kotlin plugin DSL detected in `android/build.gradle`.',
        ),
      );
      expect(
        reportSection.summary,
        contains('In the future, this might affect scoring.'),
      );
    });

    test('No warning if modern Kotlin is used', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps(
          'my_package',
          sdkConstraint: '^3.0.0',
          pubspecExtras: {
            'flutter': {
              'plugin': {
                'platforms': {
                  'android': <String, dynamic>{'pluginClass': 'MyPlugin'},
                },
              },
            },
          },
          extraFiles: [
            d.dir('android', [
              d.file('build.gradle', '''
                plugins {
                    id("com.android.library")
                }
              '''),
            ]),
          ],
        ),
      ]);
      await descriptor.create();

      final reportSection = await multiPlatform(
        PackageContext(
          sharedContext: SharedAnalysisContext(
            toolEnvironment: await ToolEnvironment.create(),
          ),
          packageDir: '${descriptor.io.path}/my_package',
        ),
      );

      expect(reportSection.grantedPoints, 20);
      expect(
        reportSection.summary,
        isNot(contains('Legacy Kotlin plugin DSL detected')),
      );
    });
  });
}
