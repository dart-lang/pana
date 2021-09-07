// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/create_report.dart';

import '../package_descriptor.dart';

void main() {
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
}
