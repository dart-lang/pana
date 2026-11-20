// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/api_diff.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../package_descriptor.dart';
import '../package_server.dart';
import '_tool_environment.dart';

void main() {
  group('apiDiffSection', () {
    test(
      'detects minor additions and breaking changes against previous hosted version',
      () async {
        await servePackages(
          (b) => b!
            ..serve(
              'my_package',
              '1.0.0',
              pubspec: {
                'environment': {'sdk': '>=3.0.0 <4.0.0'},
              },
              contents: [
                d.dir('lib', [
                  d.file('my_package.dart', '''
class Greeter {
  String greet(String name) => 'Hello, \$name!';
}
'''),
                ]),
              ],
            ),
        );

        // 1. Minor release 1.1.0 adding a method
        {
          final descriptor = package(
            'my_package',
            version: '1.1.0',
            sdkConstraint: '>=3.0.0 <4.0.0',
            lib: [
              d.file('my_package.dart', '''
class Greeter {
  String greet(String name) => 'Hello, \$name!';
  String farewell(String name) => 'Goodbye, \$name!';
}
'''),
            ],
          );
          await descriptor.create();

          final context = PackageContext(
            sharedContext: SharedAnalysisContext(
              toolEnvironment: await testToolEnvironment(),
              options: InspectOptions(
                pubHostedUrl: globalPackageServer!.url,
                runApiDiff: true,
              ),
            ),
            packageDir: descriptor.io.path,
          );

          final section = (await apiDiffSection(context))!;
          expect(section.id, ReportSectionId.apiDiff);
          expect(section.grantedPoints, 0);
          expect(section.maxPoints, 0);
          expect(section.status, ReportStatus.passed);
          expect(
            section.summary,
            contains(
              '1 non-breaking API change (0 breaking) compared to `1.0.0`',
            ),
          );
          expect(section.summary, contains('farewell'));

          final diff = (await context.apiDiffResult).summary!;
          expect(diff.previousVersion, '1.0.0');
          expect(diff.currentVersion, '1.1.0');
          expect(diff.requiredVersionBump, 'minor');
          expect(diff.minimumExpectedVersion, '1.1.0');
          expect(diff.isVersionIncrementSufficient, isTrue);
          expect(diff.breakingChanges, isEmpty);
          expect(diff.nonBreakingChanges, hasLength(1));
          expect(diff.textDiff, contains('+    farewell'));
        }

        // 2. Patch release 1.0.1 with a breaking removal + final modifier
        {
          final descriptor = package(
            'my_package',
            version: '1.0.1',
            sdkConstraint: '>=3.0.0 <4.0.0',
            lib: [
              d.file('my_package.dart', '''
final class Greeter {}
'''),
            ],
          );
          await descriptor.create();

          final context = PackageContext(
            sharedContext: SharedAnalysisContext(
              toolEnvironment: await testToolEnvironment(),
              options: InspectOptions(
                pubHostedUrl: globalPackageServer!.url,
                runApiDiff: true,
              ),
            ),
            packageDir: descriptor.io.path,
          );

          final section = (await apiDiffSection(context))!;
          expect(section.status, ReportStatus.partial);
          expect(section.summary, contains('expected `>=2.0.0`, got `1.0.1`'));

          final diff = (await context.apiDiffResult).summary!;
          expect(diff.requiredVersionBump, 'major');
          expect(diff.minimumExpectedVersion, '2.0.0');
          expect(diff.isVersionIncrementSufficient, isFalse);
          expect(diff.breakingChanges, hasLength(2));
          expect(
            diff.breakingChanges.map((c) => c.changeCode),
            containsAll(['CLASS_MODIFIER_RESTRICTED', 'MEMBER_REMOVED']),
          );
          expect(
            diff.textDiff,
            contains('+  Greeter (class extends Object, final)'),
          );
        }
      },
    );
  });
}
