// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/create_report.dart';
import 'package:pana/src/package_context.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package_descriptor.dart';
import 'package_server.dart';

void main() {
  group('Follow Dart file conventions', () {
    test('finds missing README and CHANGELOG', () async {
      final descriptor = package('my_package', extraFiles: []);
      await descriptor.create();
      final report = await createReport(PackageContext(
        toolEnvironment: await ToolEnvironment.create(),
        packageDir: descriptor.io.path,
        options: InspectOptions(),
      ));
      final section = report.sections
          .firstWhere((s) => s.title == 'Follow Dart file conventions');
      expect(section.grantedPoints, 0);
      expect(section.summary, contains('No `README.md` found'));
      expect(section.summary, contains('No `CHANGELOG.md` found'));
    });

    test('Detects insecure links', () async {
      final descriptor = package('my_package', extraFiles: [
        d.file('README.md', '''
# my_package
Check it out on [github](http://github.com/example/my_package).
![alt text](http://example.com/icon1.png "Icon1")
![alt text](http://example.com/icon1.png "Icon2")
'''),
        d.file('CHANGELOG.md', '''
## 1.0.0 First release!
'''),
      ]);
      await descriptor.create();
      final report = await createReport(PackageContext(
        toolEnvironment: await ToolEnvironment.create(),
        packageDir: descriptor.io.path,
        options: InspectOptions(),
      ));
      final section = report.sections
          .firstWhere((s) => s.title == 'Follow Dart file conventions');
      expect(section.grantedPoints, 5);
      expect(section.summary, isNot(contains('No `README.md` found')));
      expect(section.summary, isNot(contains('No `CHANGELOG.md` found')));
      expect(section.summary, contains('1 link is insecure'));
      expect(section.summary, contains('2 image links are insecure'));
    });
  });

  group('Provide documentation', () {
    test('documentation percent', () {
      expect(documentationCoverageSection(documented: 1, total: 21).summary,
          contains('(4.8 %)'));
      expect(documentationCoverageSection(documented: 0, total: 0).summary,
          contains('(100.0 %)'));
      expect(documentationCoverageSection(documented: 5, total: 7).summary,
          contains('(71.4 %)'));
      expect(documentationCoverageSection(documented: 7, total: 7).summary,
          contains('(100.0 %)'));
    });

    test('documentation title', () {
      expect(documentationCoverageSection(documented: 1, total: 21).summary,
          contains('### [x] 0/10 points'));
      expect(documentationCoverageSection(documented: 0, total: 0).summary,
          contains('### [*] 10/10 points'));
      expect(documentationCoverageSection(documented: 5, total: 7).summary,
          contains('### [*] 10/10 points'));
      expect(documentationCoverageSection(documented: 7, total: 7).summary,
          contains('### [*] 10/10 points'));
    });

    test('finds example', () async {
      final descriptor = package('my_package', extraFiles: [
        d.dir('example', [
          d.file('EXAMPLE.md', '''
# Dev setup

Use the following additional dependencies..

# Library use

Call this method..
'''),
        ]),
      ]);

      await descriptor.create();
      final report = await createReport(PackageContext(
        toolEnvironment: await ToolEnvironment.create(),
        packageDir: descriptor.io.path,
        options: InspectOptions(),
      ));
      final section =
          report.sections.firstWhere((s) => s.title == 'Provide documentation');
      expect(section.grantedPoints, 10);
      expect(section.summary, isNot(contains('No example found.')));
    });

    test('missing example', () async {
      final descriptor = package('my_package');

      await descriptor.create();
      final report = await createReport(PackageContext(
        toolEnvironment: await ToolEnvironment.create(),
        packageDir: descriptor.io.path,
        options: InspectOptions(),
      ));
      final section =
          report.sections.firstWhere((s) => s.title == 'Provide documentation');
      expect(section.grantedPoints, 0);
      expect(section.summary, contains('No example found.'));
    });
  });

  group('trustworthy dependency', () {
    test('Gives points despite outdated package', () async {
      await servePackages((b) => b
        ..serve('foo', '1.2.3',
            published: DateTime.now().subtract(const Duration(days: 2))));
      final descriptor = package('my_package',
          sdkConstraint: '>=2.10.0 <3.0.0',
          dependencies: {
            'foo': {
              'hosted': {'name': 'foo', 'url': globalPackageServer.url},
              'version': '^1.1.0'
            }
          });
      await descriptor.create();

      final context = PackageContext(
        toolEnvironment: await ToolEnvironment.create(
            // Enforce no Flutter for consistent testing.
            flutterSdkDir: null),
        packageDir: descriptor.io.path,
        options: InspectOptions(),
      );

      {
        final section = await trustworthyDependency(context);
        expect(section.grantedPoints, 10);
      }
      DateTime daysAgo(int days) =>
          DateTime.now().subtract(Duration(days: days));
      {
        globalPackageServer.add(
          (b) => b.serve('foo', '4.0.0',
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

        expect(section.grantedPoints, 10);
      }
      {
        globalPackageServer
            .add((b) => b.serve('foo', '3.0.0', published: daysAgo(3)));

        final section = await trustworthyDependency(context);
        expect(
          section.summary,
          contains(
              'The constraint `^1.1.0` on foo does not support the stable version `3.0.0`, that was published 3 days ago.'),
        );

        expect(section.grantedPoints, 10);
      }
      {
        globalPackageServer.add(
          (b) => b.serve(
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
        expect(section.grantedPoints, 0);
      }
    });
  });
}
