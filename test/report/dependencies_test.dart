// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/dependencies.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../package_descriptor.dart';
import '../package_server.dart';
import '_tool_environment.dart';

void main() {
  group('trustworthy dependency', () {
    test('Gives points despite outdated package', () async {
      await servePackages(
        (b) => b!
          ..serve(
            'foo',
            '1.2.3',
            published: DateTime.now().subtract(const Duration(days: 2)),
          ),
      );
      final descriptor = package(
        'my_package',
        sdkConstraint: '>=2.14.0 <4.0.0',
        dependencies: {
          'foo': {
            'hosted': {'name': 'foo', 'url': globalPackageServer!.url},
            'version': '^1.1.0',
          },
        },
      );
      await descriptor.create();

      Future<PackageContext> newContext() async => PackageContext(
        sharedContext: SharedAnalysisContext(
          toolEnvironment: await testToolEnvironment(),
        ),
        packageDir: descriptor.io.path,
      );
      final currentSdkVersion = Version.parse(
        (await testToolEnvironment()).runtimeInfo.sdkVersion,
      );

      {
        final section = await trustworthyDependency(await newContext());
        expect(section.grantedPoints, section.maxPoints);
      }
      DateTime daysAgo(int days) =>
          DateTime.now().subtract(Duration(days: days));
      {
        globalPackageServer!.add(
          (b) => b!.serve(
            'foo',
            '4.0.0',
            pubspec: {
              'environment': {
                'sdk': VersionConstraint.compatibleWith(
                  currentSdkVersion.nextBreaking,
                ).toString(),
              },
            },
            published: daysAgo(200),
          ),
        );

        final section = await trustworthyDependency(await newContext());
        expect(
          section.summary,
          contains(
            '* The constraint `^1.1.0` on foo does not support the stable version `4.0.0`, '
            'but that version doesn\'t support the current Dart SDK version $currentSdkVersion',
          ),
        );

        expect(section.grantedPoints, section.maxPoints);
      }
      {
        globalPackageServer!.add(
          (b) => b!.serve('foo', '3.0.0', published: daysAgo(3)),
        );

        final section = await trustworthyDependency(await newContext());
        expect(
          section.summary,
          contains(
            'The constraint `^1.1.0` on foo does not support the stable version `3.0.0`, that was published 3 days ago.',
          ),
        );

        expect(section.grantedPoints, section.maxPoints);
      }
      {
        globalPackageServer!.add(
          (b) => b!.serve(
            'foo',
            '2.0.0',
            pubspec: {
              'environment': {
                'sdk': VersionConstraint.compatibleWith(
                  currentSdkVersion,
                ).toString(),
              },
            },
            published: daysAgo(200),
          ),
        );

        final section = await trustworthyDependency(await newContext());
        expect(
          section.summary,
          contains(
            'The constraint `^1.1.0` on foo does not support the stable version `2.0.0`.',
          ),
        );
        expect(section.grantedPoints, section.maxPoints - 10);
      }
    });

    test('ignores Flutter constraint upper bound', () async {
      final descriptor = package(
        'my_package',
        pubspecExtras: {
          'environment': {'sdk': '>=3.0.0 <4.0.0', 'flutter': '>=2.6.0 <3.0.0'},
        },
      );
      await descriptor.create();
      final context = PackageContext(
        sharedContext: SharedAnalysisContext(
          toolEnvironment: await ToolEnvironment.create(),
        ),
        packageDir: descriptor.io.path,
      );
      final section = await trustworthyDependency(context);
      expect(section.grantedPoints, section.maxPoints);
    });

    test('Understands `>=2.12.0 <3.0.0` as `>=2.12.0 <4.0.0`', () async {
      final descriptor = package(
        'my_package',
        pubspecExtras: {
          'environment': {'sdk': '>=2.12.0 <3.0.0'},
        },
      );
      await descriptor.create();
      final context = PackageContext(
        sharedContext: SharedAnalysisContext(
          toolEnvironment: await testToolEnvironment(sdkVersion: '3.0.0'),
        ),
        packageDir: descriptor.io.path,
      );
      final section = await trustworthyDependency(context);
      expect(section.grantedPoints, section.maxPoints);
    });

    test('complains about Flutter constraint upper bound', () async {
      final toolEnv = await ToolEnvironment.create();
      final version = int.parse(
        toolEnv.runtimeInfo.flutterVersion?.split('.').first ?? '4',
      );
      final nextVersion = version + 1;
      final descriptor = package(
        'my_package',
        pubspecExtras: {
          'environment': {
            'sdk': '>=3.0.0 <4.0.0',
            'flutter': '>=$nextVersion.0.0 <${nextVersion + 1}.0.0',
          },
        },
      );
      await descriptor.create();
      final context = PackageContext(
        sharedContext: SharedAnalysisContext(toolEnvironment: toolEnv),
        packageDir: descriptor.io.path,
      );
      final section = await trustworthyDependency(context);
      expect(
        section.summary,
        contains(
          'The current flutter constraint does not allow the latest Flutter',
        ),
      );
      expect(section.grantedPoints, 0);
    });

    test(
      'pub outdated ignores dev_dependencies while static analysis includes them',
      () async {
        await servePackages(
          (b) => b!
            ..serve(
              'hosted_dep',
              '1.0.0',
              contents: [d.file('lib.dart', 'const hostedValue = 1;')],
            )
            ..serve(
              'hosted_dev_dep',
              '1.0.0',
              contents: [d.file('lib.dart', 'const devValue = 2;')],
            ),
        );

        final descriptor = package(
          'my_package',
          sdkConstraint: '>=3.0.0 <4.0.0',
          dependencies: {'hosted_dep': '^1.0.0'},
          pubspecExtras: {
            'dev_dependencies': {
              'hosted_dev_dep': '^1.0.0',
              // Path dev_dep should be stripped and not cause failure
              'broken_path_dev_dep': {'path': '../does_not_exist'},
            },
          },
          lib: [
            d.file('my_package.dart', '''
import 'package:hosted_dep/lib.dart';
void main() {
  print(hostedValue);
}
'''),
          ],
        );
        await descriptor.create();

        final context = PackageContext(
          sharedContext: SharedAnalysisContext(
            toolEnvironment: await testToolEnvironment(),
          ),
          packageDir: descriptor.io.path,
        );

        // Outdated should only include hosted_dep, NOT hosted_dev_dep
        final outdated = await context.outdated;
        final packageNames = outdated.packages.map((p) => p.package).toList();
        expect(packageNames, contains('hosted_dep'));
        expect(packageNames, isNot(contains('hosted_dev_dep')));
        expect(packageNames, isNot(contains('broken_path_dev_dep')));

        // Static analysis should succeed
        final analysisResult = await context.staticAnalysis;
        expect(analysisResult.hasError, isFalse);
      },
    );
  });
}
