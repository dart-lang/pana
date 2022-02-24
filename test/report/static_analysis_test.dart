// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/report/static_analysis.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('bad cr position', () async {
    await withTempDir((dir) async {
      final file = File(p.join(dir, 'cr.txt'));
      await file.writeAsString('abcd efgh\r\n\r\n1234\r\n\r\nxyz');
      final s1 =
          sourceSpanFromFile(path: file.path, line: 1, col: 6, length: 7);
      expect(s1!.text, 'efgh\r\n');
      final s2 =
          sourceSpanFromFile(path: file.path, line: 1, col: 10, length: 8);
      expect(s2!.text, '\n\r\n1234');
    });
  });
}
