// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/dependencies.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../package_descriptor.dart';
import '../package_server.dart';
import '_tool_environment.dart';

void main() {
  group('trustworthy dependency', () {
    test('Gives points despite outdated package', () async {
      await servePackages((b) => b!
        ..serve('foo', '1.2.3',
            published: DateTime.now().subtract(const Duration(days: 2))));
      final descriptor = package('my_package',
          sdkConstraint: '>=2.14.0 <4.0.0',
          dependencies: {
            'foo': {
              'hosted': {'name': 'foo', 'url': globalPackageServer!.url},
              'version': '^1.1.0'
            }
          });
      await descriptor.create();

      Future<PackageContext> newContext() async => PackageContext(
            sharedContext: SharedAnalysisContext(
              toolEnvironment: await testToolEnvironment(),
            ),
            packageDir: descriptor.io.path,
          );
      final currentSdkVersion =
          Version.parse((await testToolEnvironment()).runtimeInfo.sdkVersion);

      {
        final section = await trustworthyDependency(await newContext());
        expect(section.grantedPoints, 20);
      }
      DateTime daysAgo(int days) =>
          DateTime.now().subtract(Duration(days: days));
      {
        globalPackageServer!.add(
          (b) => b!.serve('foo', '4.0.0',
              pubspec: {
                'environment': {
                  'sdk': VersionConstraint.compatibleWith(
                          currentSdkVersion.nextBreaking)
                      .toString()
                }
              },
              published: daysAgo(200)),
        );

        final section = await trustworthyDependency(await newContext());
        expect(
            section.summary,
            contains(
                '* The constraint `^1.1.0` on foo does not support the stable version `4.0.0`, '
                'but that version doesn\'t support the current Dart SDK version $currentSdkVersion'));

        expect(section.grantedPoints, 20);
      }
      {
        globalPackageServer!
            .add((b) => b!.serve('foo', '3.0.0', published: daysAgo(3)));

        final section = await trustworthyDependency(await newContext());
        expect(
          section.summary,
          contains(
              'The constraint `^1.1.0` on foo does not support the stable version `3.0.0`, that was published 3 days ago.'),
        );

        expect(section.grantedPoints, 20);
      }
      {
        globalPackageServer!.add(
          (b) => b!.serve(
            'foo',
            '2.0.0',
            pubspec: {
              'environment': {
                'sdk': VersionConstraint.compatibleWith(currentSdkVersion)
                    .toString()
              }
            },
            published: daysAgo(200),
          ),
        );

        final section = await trustworthyDependency(await newContext());
        expect(
          section.summary,
          contains(
              'The constraint `^1.1.0` on foo does not support the stable version `2.0.0`.'),
        );
        expect(section.grantedPoints, 10);
      }
    });

    test('ignores Flutter constraint upper bound', () async {
      final descriptor = package('my_package', pubspecExtras: {
        'environment': {
          'sdk': '>=3.0.0 <4.0.0',
          'flutter': '>=2.6.0 <3.0.0',
        }
      });
      await descriptor.create();
      final context = PackageContext(
        sharedContext: SharedAnalysisContext(
          toolEnvironment: await ToolEnvironment.create(),
        ),
        packageDir: descriptor.io.path,
      );
      final section = await trustworthyDependency(context);
      expect(section.grantedPoints, 20);
    });

    test('Understands `>=2.12.0 <3.0.0` as `>=2.12.0 <4.0.0`', () async {
      final descriptor = package('my_package', pubspecExtras: {
        'environment': {
          'sdk': '>=2.12.0 <3.0.0',
        }
      });
      await descriptor.create();
      final context = PackageContext(
        sharedContext: SharedAnalysisContext(
          toolEnvironment: await testToolEnvironment(sdkVersion: '3.0.0'),
        ),
        packageDir: descriptor.io.path,
      );
      final section = await trustworthyDependency(context);
      expect(section.grantedPoints, 20);
    });

    test('complains about Flutter constraint upper bound', () async {
      final toolEnv = await ToolEnvironment.create();
      final version = int.parse(
          toolEnv.runtimeInfo.flutterVersion?.split('.').first ?? '4');
      final nextVersion = version + 1;
      final descriptor = package('my_package', pubspecExtras: {
        'environment': {
          'sdk': '>=3.0.0 <4.0.0',
          'flutter': '>=$nextVersion.0.0 <${nextVersion + 1}.0.0',
        }
      });
      await descriptor.create();
      final context = PackageContext(
        sharedContext: SharedAnalysisContext(
          toolEnvironment: toolEnv,
        ),
        packageDir: descriptor.io.path,
      );
      final section = await trustworthyDependency(context);
      expect(
          section.summary,
          contains(
              'The current flutter constraint does not allow the latest Flutter'));
      expect(section.grantedPoints, 0);
    });
  });
}
