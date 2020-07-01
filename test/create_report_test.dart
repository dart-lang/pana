// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/create_report.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package_descriptor.dart';

void main() {
  group('Packaging conventions', () {
    test('finds missing README and CHANGELOG', () async {
      final descriptor = package('my_package', extraFiles: []);
      await descriptor.create();
      final report = await createReport(
          descriptor.io.path, await ToolEnvironment.create());
      final section =
          report.sections.firstWhere((s) => s.title == 'Packaging conventions');
      expect(section.grantedPoints, 0);
      expect(section.summary, contains('No README.md found'));
      expect(section.summary, contains('No CHANGELOG.md found'));
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
      final report = await createReport(
          descriptor.io.path, await ToolEnvironment.create());
      final section =
          report.sections.firstWhere((s) => s.title == 'Packaging conventions');
      expect(section.grantedPoints, 5);
      expect(section.summary, isNot(contains('No README.md found')));
      expect(section.summary, isNot(contains('No CHANGELOG.md found')));
      expect(section.summary, contains('1 link is insecure'));
      expect(section.summary, contains('2 image links are insecure'));
    });
  });

  group('Package has documentation', () {
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
      final report = await createReport(
          descriptor.io.path, await ToolEnvironment.create());
      final section = report.sections
          .firstWhere((s) => s.title == 'Package has documentation');
      expect(section.grantedPoints, 10);
      expect(section.summary, isNot(contains('No example found.')));
    });

    test('missing example', () async {
      final descriptor = package('my_package');

      await descriptor.create();
      final report = await createReport(
          descriptor.io.path, await ToolEnvironment.create());
      final section = report.sections
          .firstWhere((s) => s.title == 'Package has documentation');
      expect(section.grantedPoints, 0);
      expect(section.summary, contains('No example found.'));
    });
  });
}
