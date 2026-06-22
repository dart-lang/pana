// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('sorted json', () {
    expect(
      json.encode(
        sortedJson({
          'b': [
            {'e': 3, 'd': 4},
          ],
          'a': 2,
        }),
      ),
      '{"a":2,"b":[{"d":4,"e":3}]}',
    );
  });

  group('runes', () {
    test('empty', () {
      expect(nonAsciiRuneRatio(null), 0.0);
      expect(nonAsciiRuneRatio(''), 0.0);
      expect(nonAsciiRuneRatio('  \t\n\r'), 0.0);
    });

    test('ascii text', () {
      expect(nonAsciiRuneRatio('a'), 0.0);
      expect(nonAsciiRuneRatio('a b c'), 0.0);
    });

    test('non-ascii text', () {
      expect(nonAsciiRuneRatio('封装http业务接口'), 0.6);
    });
  });

  group('analysisTargetPaths', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('pana-analysis-targets');
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('only existing targets are returned', () {
      expect(analysisTargetPaths(dir.path), ['pubspec.yaml']);

      Directory(p.join(dir.path, 'lib')).createSync();
      expect(analysisTargetPaths(dir.path), ['pubspec.yaml', 'lib']);

      Directory(p.join(dir.path, 'bin')).createSync();
      expect(analysisTargetPaths(dir.path), ['pubspec.yaml', 'bin', 'lib']);
    });

    test('non-target directories are excluded', () {
      Directory(p.join(dir.path, 'lib')).createSync();
      Directory(p.join(dir.path, 'test')).createSync();
      Directory(p.join(dir.path, 'example')).createSync();
      expect(analysisTargetPaths(dir.path), ['pubspec.yaml', 'lib']);
    });
  });
}
