// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/src/dartdoc/dartdoc_options.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('normalizeDartdocOptionsYaml', () {
    test('normalizes existing dartdoc_options.yaml', () async {
      await withTempDir((dir) async {
        final file = File(p.join(dir, 'dartdoc_options.yaml'));
        await file.writeAsString('''
dartdoc:
  include: ['lib/foo.dart']
  custom_flag: true
''');

        await normalizeDartdocOptionsYaml(dir);

        final content =
            json.decode(await file.readAsString()) as Map<String, dynamic>;
        expect(content, {
          'dartdoc': {
            'include': ['lib/foo.dart'],
            'showUndocumentedCategories': true,
          },
        });
      });
    });

    test('creates default options if file does not exist', () async {
      await withTempDir((dir) async {
        final file = File(p.join(dir, 'dartdoc_options.yaml'));
        expect(await file.exists(), isFalse);

        await normalizeDartdocOptionsYaml(dir);

        expect(await file.exists(), isTrue);
        final content =
            json.decode(await file.readAsString()) as Map<String, dynamic>;
        expect(content, {
          'dartdoc': {'showUndocumentedCategories': true},
        });
      });
    });

    test(
      'replaces dangling symlink without creating out-of-tree target',
      () async {
        await withTempDir((dir) async {
          final outsideDir = await Directory.systemTemp.createTemp('outside_');
          try {
            final outsideTarget = p.join(outsideDir.path, 'canary.txt');
            final symlink = Link(p.join(dir, 'dartdoc_options.yaml'));
            await symlink.create(outsideTarget);

            expect(await File(outsideTarget).exists(), isFalse);

            await normalizeDartdocOptionsYaml(dir);

            // Target file outside should not be created.
            expect(await File(outsideTarget).exists(), isFalse);

            // Options file in package dir should now be a regular file.
            final optionsFile = File(p.join(dir, 'dartdoc_options.yaml'));
            expect(
              await FileSystemEntity.type(optionsFile.path, followLinks: false),
              FileSystemEntityType.file,
            );
            final content =
                json.decode(await optionsFile.readAsString())
                    as Map<String, dynamic>;
            expect(content, {
              'dartdoc': {'showUndocumentedCategories': true},
            });
          } finally {
            await outsideDir.delete(recursive: true);
          }
        });
      },
    );

    test(
      'replaces symlink to existing file without modifying target',
      () async {
        await withTempDir((dir) async {
          final outsideDir = await Directory.systemTemp.createTemp('outside_');
          try {
            final outsideTarget = File(p.join(outsideDir.path, 'target.yaml'));
            await outsideTarget.writeAsString('original: content\n');

            final symlink = Link(p.join(dir, 'dartdoc_options.yaml'));
            await symlink.create(outsideTarget.path);

            await normalizeDartdocOptionsYaml(dir);

            // Target file outside should be unchanged.
            expect(await outsideTarget.readAsString(), 'original: content\n');

            // Options file in package dir should now be a regular file.
            final optionsFile = File(p.join(dir, 'dartdoc_options.yaml'));
            expect(
              await FileSystemEntity.type(optionsFile.path, followLinks: false),
              FileSystemEntityType.file,
            );
          } finally {
            await outsideDir.delete(recursive: true);
          }
        });
      },
    );
  });
}
