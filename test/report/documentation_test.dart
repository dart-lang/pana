// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/create_report.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../package_descriptor.dart';

void main() {
  group('Provide documentation', () {
    test('finds example', () async {
      final descriptor = package(
        'my_package',
        extraFiles: [
          d.dir('example', [
            d.file('example.md', '''
# Dev setup

Use the following additional dependencies..

# Library use

Call this method..
'''),
          ]),
        ],
      );

      await descriptor.create();
      final report = await createReport(
        PackageContext(
          sharedContext: SharedAnalysisContext(
            toolEnvironment: await ToolEnvironment.create(),
          ),
          packageDir: descriptor.io.path,
        ),
      );
      final section = report.sections.firstWhere(
        (s) => s.title == 'Provide documentation',
      );
      expect(section.grantedPoints, 10);
      expect(section.summary, isNot(contains('No example found.')));
    });

    test('missing example', () async {
      final descriptor = package('my_package');

      await descriptor.create();
      final report = await createReport(
        PackageContext(
          sharedContext: SharedAnalysisContext(
            toolEnvironment: await ToolEnvironment.create(),
          ),
          packageDir: descriptor.io.path,
        ),
      );
      final section = report.sections.firstWhere(
        (s) => s.title == 'Provide documentation',
      );
      expect(section.grantedPoints, 0);
      expect(section.summary, contains('No example found.'));
    });
  });
}
