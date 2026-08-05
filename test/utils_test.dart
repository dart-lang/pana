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

  group('yamlToJson', () {
    test('null or non-map input returns null', () {
      expect(yamlToJson(null), isNull);
      expect(yamlToJson(''), isNull);
      expect(yamlToJson('   '), isNull);
      expect(yamlToJson('123'), isNull);
      expect(yamlToJson('"hello"'), isNull);
      expect(yamlToJson('- a\n- b'), isNull);
    });

    test('valid yaml map with sorted keys', () {
      final yaml = '''
b:
  d: 4
  c: 3
a: 2
''';
      expect(yamlToJson(yaml), {
        'a': 2,
        'b': {'c': 3, 'd': 4},
      });
    });

    test('valid yaml with reasonable alias expansion', () {
      final yaml = '''
default: &default
  timeout: 30
service1:
  <<: *default
  name: s1
service2:
  <<: *default
  name: s2
''';
      expect(yamlToJson(yaml), {
        'default': {'timeout': 30},
        'service1': {
          '<<': {'timeout': 30},
          'name': 's1',
        },
        'service2': {
          '<<': {'timeout': 30},
          'name': 's2',
        },
      });
    });

    test('rejects YAML alias expansion bomb (billion laughs)', () {
      final bomb = '''
a: &a ["lol","lol","lol","lol","lol","lol","lol","lol","lol","lol"]
b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a,*a]
c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b,*b]
d: &d [*c,*c,*c,*c,*c,*c,*c,*c,*c,*c]
e: &e [*d,*d,*d,*d,*d,*d,*d,*d,*d,*d]
f: &f [*e,*e,*e,*e,*e,*e,*e,*e,*e,*e]
g: &g [*f,*f,*f,*f,*f,*f,*f,*f,*f,*f]
h: &h [*g,*g,*g,*g,*g,*g,*g,*g,*g,*g]
''';
      expect(
        () => yamlToJson(bomb),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('maximum allowed node count'),
          ),
        ),
      );
    });

    test('rejects cyclic YAML references', () {
      final cyclic = '''
a: &a
  b: *a
''';
      expect(
        () => yamlToJson(cyclic),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Cyclic reference detected'),
          ),
        ),
      );
    });

    test('rejects YAML exceeding max depth', () {
      final deep = '${List.generate(70, (i) => '${'  ' * i}a:').join('\n')} 1';
      expect(
        () => yamlToJson(deep, maxDepth: 64),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('maximum allowed depth'),
          ),
        ),
      );
    });

    test('respects custom maxNodes limit', () {
      final yaml = '''
a: [1, 2, 3, 4, 5]
b: [6, 7, 8, 9, 10]
''';
      expect(
        () => yamlToJson(yaml, maxNodes: 5),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('maximum allowed node count'),
          ),
        ),
      );
    });
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
