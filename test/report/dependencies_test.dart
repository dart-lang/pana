// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/dependencies.dart';

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
          sdkConstraint: '>=2.10.0 <3.0.0',
          dependencies: {
            'foo': {
              'hosted': {'name': 'foo', 'url': globalPackageServer!.url},
              'version': '^1.1.0'
            }
          });
      await descriptor.create();

      final context = PackageContext(
        toolEnvironment: await testToolEnvironment(),
        packageDir: descriptor.io.path,
        options: InspectOptions(),
      );

      {
        final section = await trustworthyDependency(context);
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
                          context.currentSdkVersion.nextBreaking)
                      .toString()
                }
              },
              published: daysAgo(200)),
        );

        final section = await trustworthyDependency(context);
        expect(
            section.summary,
            contains(
                '* The constraint `^1.1.0` on foo does not support the stable version `4.0.0`, '
                'but that version doesn\'t support the current Dart SDK version ${context.currentSdkVersion}'));

        expect(section.grantedPoints, 20);
      }
      {
        globalPackageServer!
            .add((b) => b!.serve('foo', '3.0.0', published: daysAgo(3)));

        final section = await trustworthyDependency(context);
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
                'sdk':
                    VersionConstraint.compatibleWith(context.currentSdkVersion)
                        .toString()
              }
            },
            published: daysAgo(200),
          ),
        );

        final section = await trustworthyDependency(context);
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
          'sdk': '>=2.10.0 <3.0.0',
          'flutter': '>=1.6.0 <2.0.0',
        }
      });
      await descriptor.create();
      final context = PackageContext(
        toolEnvironment: await testToolEnvironment(),
        packageDir: descriptor.io.path,
        options: InspectOptions(),
      );
      final section = await trustworthyDependency(context);
      expect(section.grantedPoints, 20);
    });
    test('complains abpout Flutter constraint upper bound', () async {
      final descriptor = package('my_package', pubspecExtras: {
        'environment': {
          'sdk': '>=2.10.0 <3.0.0',
          'flutter': '>=3.0.0 <4.0.0',
        }
      });
      await descriptor.create();
      final context = PackageContext(
        toolEnvironment: await testToolEnvironment(),
        packageDir: descriptor.io.path,
        options: InspectOptions(),
      );
      final section = await trustworthyDependency(context);
      expect(
          section.summary,
          contains(
              'The current flutter constraint does not allow the latest Flutter (2.0.0)'));
      expect(section.grantedPoints, 0);
    });
  });
}
