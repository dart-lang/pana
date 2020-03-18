// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:pana/src/code_problem.dart';

void main() {
  test('windows double escape', () {
    final cp = parseCodeProblem(
        r"INFO|HINT|UNUSED_FIELD|D:\\Documents\\youtube_explode_dart\\lib\\src\\extensions\\helpers_extension.dart|16|16|4|The value of the field '_exp' isn't used.");
    expect(cp.file,
        r'D:\Documents\youtube_explode_dart\lib\src\extensions\helpers_extension.dart');
  });
}
