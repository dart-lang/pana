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

  group('listFiles', () {
    test('lists files in directory and subdirectories', () async {
      await withTempDir((dir) async {
        File(p.join(dir, 'a.txt')).writeAsStringSync('a');
        final subDir = Directory(p.join(dir, 'sub'))..createSync();
        File(p.join(subDir.path, 'b.txt')).writeAsStringSync('b');
        final nestedDir = Directory(p.join(subDir.path, 'nested'))
          ..createSync();
        File(p.join(nestedDir.path, 'c.dart')).writeAsStringSync('c');

        final files = await listFiles(dir).toList();
        expect(
          files,
          unorderedEquals([
            'a.txt',
            p.join('sub', 'b.txt'),
            p.join('sub', 'nested', 'c.dart'),
          ]),
        );
      });
    });

    test('filters by endsWith', () async {
      await withTempDir((dir) async {
        File(p.join(dir, 'a.txt')).writeAsStringSync('a');
        final subDir = Directory(p.join(dir, 'sub'))..createSync();
        File(p.join(subDir.path, 'b.dart')).writeAsStringSync('b');

        final files = await listFiles(dir, endsWith: '.dart').toList();
        expect(files, [p.join('sub', 'b.dart')]);
      });
    });

    test(
      'deletes invalid AppleDouble files when deleteBadExtracted is true',
      () async {
        await withTempDir((dir) async {
          final badFile = File(p.join(dir, '._bad.txt'))
            ..writeAsStringSync('bad');
          final subDir = Directory(p.join(dir, 'sub'))..createSync();
          final nestedBadFile = File(p.join(subDir.path, '._nested.dart'))
            ..writeAsStringSync('bad');
          File(p.join(dir, 'good.txt')).writeAsStringSync('good');

          expect(badFile.existsSync(), isTrue);
          expect(nestedBadFile.existsSync(), isTrue);

          final files = await listFiles(dir, deleteBadExtracted: true).toList();
          expect(files, ['good.txt']);
          expect(badFile.existsSync(), isFalse);
          expect(nestedBadFile.existsSync(), isFalse);
        });
      },
    );

    test(
      'does not follow directory symlinks and does not delete out-of-tree files',
      () async {
        await withTempDir((dir) async {
          final outsideDir = await Directory.systemTemp.createTemp('outside_');
          try {
            final outsideBadFile = File(
              p.join(outsideDir.path, '._outside.txt'),
            )..writeAsStringSync('secret');
            final outsideGoodFile = File(
              p.join(outsideDir.path, 'outside.dart'),
            )..writeAsStringSync('code');

            // Create a symlink to outsideDir inside dir
            final link = Link(p.join(dir, 'symlink_dir'));
            await link.create(outsideDir.path);

            File(p.join(dir, 'local.dart')).writeAsStringSync('local');

            final files = await listFiles(
              dir,
              deleteBadExtracted: true,
            ).toList();

            // Only local file should be returned
            expect(files, ['local.dart']);

            // Out-of-tree files should be intact
            expect(outsideBadFile.existsSync(), isTrue);
            expect(outsideGoodFile.existsSync(), isTrue);
          } finally {
            await outsideDir.delete(recursive: true);
          }
        });
      },
    );

    test(
      'does not follow file symlinks and does not delete out-of-tree target file',
      () async {
        await withTempDir((dir) async {
          final outsideDir = await Directory.systemTemp.createTemp('outside_');
          try {
            final outsideBadFile = File(p.join(outsideDir.path, '._target.txt'))
              ..writeAsStringSync('secret');

            // Create a file symlink inside dir pointing to outside bad file
            final link = Link(p.join(dir, 'symlink_file'));
            await link.create(outsideBadFile.path);

            final files = await listFiles(
              dir,
              deleteBadExtracted: true,
            ).toList();

            expect(files, isEmpty);
            expect(outsideBadFile.existsSync(), isTrue);
          } finally {
            await outsideDir.delete(recursive: true);
          }
        });
      },
    );

    test('handles cyclic directory symlinks safely', () async {
      await withTempDir((dir) async {
        final subDir = Directory(p.join(dir, 'sub'))..createSync();
        File(p.join(dir, 'a.txt')).writeAsStringSync('a');

        // Create a cyclic symlink: sub/loop -> dir
        final link = Link(p.join(subDir.path, 'loop'));
        await link.create(dir);

        final files = await listFiles(dir).toList();
        expect(files, ['a.txt']);
      });
    });
  });

  group('dartFilesFromLib', () {
    test('does not follow symlinks outside package lib', () async {
      await withTempDir((dir) async {
        final outsideDir = await Directory.systemTemp.createTemp('outside_');
        try {
          File(
            p.join(outsideDir.path, 'outside.dart'),
          ).writeAsStringSync('void f() {}');
          final libDir = Directory(p.join(dir, 'lib'))..createSync();
          File(
            p.join(libDir.path, 'local.dart'),
          ).writeAsStringSync('void g() {}');

          final link = Link(p.join(libDir.path, 'outside_lib'));
          await link.create(outsideDir.path);

          final dartFiles = dartFilesFromLib(dir);
          expect(dartFiles, ['local.dart']);
        } finally {
          await outsideDir.delete(recursive: true);
        }
      });
    });
  });
}
