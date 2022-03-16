// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:pana/src/license.dart';
import 'package:test/test.dart';

void main() {
  Future expectFile(String path, expected) async {
    final relativePath = path.substring('test/licenses/'.length);
    final licenses =
        await detectLicenseInFile(File(path), relativePath: relativePath);
    expect(licenses.map((e) => e.spdx).toList(), expected);
  }

  test('bad encoding', () async {
    await expectFile('test/licenses/bad_encoding.txt', ['Zlib']);
  });

  group('AGPL', () {
    test('explicit', () async {
      expect(
          await detectLicenseInContent('GNU AFFERO GENERAL PUBLIC LICENSE',
              relativePath: 'LICENSE'),
          []);
      await expectFile('test/licenses/agpl_v3.txt', ['AGPL-3.0']);
    });
  });

  group('Apache', () {
    test('explicit', () async {
      expect(
          await detectLicenseInContent(
              '   Apache License\n     Version 2.0, January 2004\n',
              relativePath: 'LICENSE'),
          []);
      await expectFile('test/licenses/apache_v2.txt', ['Apache-2.0']);
    });
  });

  group('BSD', () {
    test('explicit', () async {
      await expectFile('test/licenses/bsd_2_clause.txt', ['BSD-2-Clause']);
      await expectFile(
          'test/licenses/bsd_2_clause_in_comments.txt', ['BSD-2-Clause']);
      await expectFile('test/licenses/bsd_3_clause.txt', ['unknown']);
      await expectFile('test/licenses/bsd_revised.txt', ['BSD-3-Clause']);
    });
  });

  group('GPL', () {
    test('explicit', () async {
      expect(
          await detectLicenseInContent(
              ['GNU GENERAL PUBLIC LICENSE', 'Version 2, June 1991'].join('\n'),
              relativePath: 'LICENSE'),
          []);
      expect(
          await detectLicenseInContent(['GNU GPL Version 2'].join('\n'),
              relativePath: 'LICENSE'),
          []);
      await expectFile('test/licenses/gpl_v3.txt', ['GPL-3.0']);
    });
  });

  group('LGPL', () {
    test('explicit', () async {
      expect(
          await detectLicenseInContent(
              '\nGNU LESSER GENERAL PUBLIC LICENSE\n    Version 3, 29 June 2007',
              relativePath: 'LICENSE'),
          []);
      await expectFile('test/licenses/lgpl_v3.txt', ['LGPL-3.0']);
    });
  });

  group('MIT', () {
    test('explicit', () async {
      expect(
          await detectLicenseInContent('\n\n   The MIT license\n\n blah...',
              relativePath: 'LICENSE'),
          []);
      expect(
          await detectLicenseInContent('MIT license\n\n blah...',
              relativePath: 'LICENSE'),
          []);

      await expectFile('test/licenses/mit.txt', ['MIT']);
      await expectFile('test/licenses/mit_without_mit.txt', ['MIT']);
    });
  });

  group('MPL', () {
    test('explicit', () async {
      expect(
          await detectLicenseInContent(
              '\n\n   Mozilla Public License Version 2.0\n\n blah...',
              relativePath: 'LICENSE'),
          []);
      await expectFile('test/licenses/mpl_v2.txt', ['MPL-2.0']);
    });
  });

  group('Unlicense', () {
    test('explicit', () async {
      expect(
          await detectLicenseInContent(
              '\n\n   This is free and unencumbered software released into the public domain.\n',
              relativePath: 'LICENSE'),
          []);
      await expectFile('test/licenses/unlicense.txt', ['Unlicense']);
    });
  });

  group('unknown', () {
    test('empty content', () async {
      expect(await detectLicenseInContent('', relativePath: 'LICENSE'), []);
    });
  });

  group('Directory scans', () {
    test('detect pana LICENSE', () async {
      final licenses = await detectLicenseInDir('.');
      expect(licenses.map((e) => e.toJson()).toList(), [
        {
          'path': 'LICENSE',
          'spdx': 'BSD-3-Clause',
        }
      ]);
    });

    test('no license files', () async {
      expect(await detectLicenseInDir('lib/src/'), []);
    });
  });
}
