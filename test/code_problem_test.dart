// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/code_problem.dart';
import 'package:pana/src/tool/run_constrained.dart';
import 'package:test/test.dart';

void main() {
  test('windows double escape', () {
    final cp = parseCodeProblem(
      r"INFO|HINT|UNUSED_FIELD|D:\\Documents\\youtube_explode_dart\\lib\\src\\extensions\\helpers_extension.dart|16|16|4|The value of the field '_exp' isn't used.",
    )!;
    expect(
      cp.file,
      r'D:\Documents\youtube_explode_dart\lib\src\extensions\helpers_extension.dart',
    );
  });

  test('too many lines', () {
    final cp = parseCodeProblem('STDERR exceeded 100000 lines.')!;
    expect(cp.description, 'Analysis returned too many issues.');
  });

  test('analysis server failure', () {
    expect(
      () => parseCodeProblem('Please report this at dartbug.com.'),
      throwsA(isA<ToolException>()),
    );
  });
}
