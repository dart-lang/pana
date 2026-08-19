// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/static_analysis.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../package_descriptor.dart';
import '../package_server.dart';
import '_tool_environment.dart';

void main() {
  test('bad cr position', () async {
    await withTempDir((dir) async {
      final file = File(p.join(dir, 'cr.txt'));
      await file.writeAsString('abcd efgh\r\n\r\n1234\r\n\r\nxyz');
      final s1 = sourceSpanFromFile(
        path: file.path,
        line: 1,
        col: 6,
        length: 7,
      );
      expect(s1!.text, 'efgh\r\n');
      final s2 = sourceSpanFromFile(
        path: file.path,
        line: 1,
        col: 10,
        length: 8,
      );
      expect(s2!.text, '\n\r\n1234');
    });
  });

  test('static analysis includes hosted dev_dependencies', () async {
    await servePackages(
      (b) => b!
        ..serve(
          'test_lints',
          '1.0.0',
          contents: [d.file('lib.dart', 'const lintConstant = 1;')],
        ),
    );

    final descriptor = package(
      'my_package',
      sdkConstraint: '>=3.0.0 <4.0.0',
      pubspecExtras: {
        'dev_dependencies': {'test_lints': '^1.0.0'},
      },
      lib: [d.file('my_package.dart', 'void main() {}')],
      extraFiles: [
        d.dir('example', [
          d.file('main.dart', '''
import 'package:test_lints/lib.dart';
void main() {
  print(lintConstant);
}
'''),
        ]),
      ],
    );
    await descriptor.create();

    final context = PackageContext(
      sharedContext: SharedAnalysisContext(
        toolEnvironment: await testToolEnvironment(),
      ),
      packageDir: descriptor.io.path,
    );

    final result = await context.staticAnalysis;
    expect(result.hasError, isFalse);
    expect(
      result.items!.where((i) => i.errorCode != 'SECURE_PUBSPEC_URLS'),
      isEmpty,
    );
  });
}
