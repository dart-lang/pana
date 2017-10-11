// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'package:pana/src/license.dart';

main() {
  Future expectFile(String path, License expected) async {
    expect(await detectLicenseInFile(new File(path)), expected);
  }

  group('AGPL', () {
    test('explicit', () async {
      expect(detectLicenseInContent('GNU AFFERO GENERAL PUBLIC LICENSE'),
          new License('AGPL'));
      await expectFile('test/licenses/agpl_v3.txt', new License('AGPL', '3.0'));
    });
  });

  group('Apache', () {
    test('explicit', () async {
      expect(
          detectLicenseInContent(
              '   Apache License\n     Version 2.0, January 2004\n'),
          new License('Apache', '2.0'));
      await expectFile(
          'test/licenses/apache_v2.txt', new License('Apache', '2.0'));
    });
  });

  group('BSD', () {
    test('detect project LICENSE', () async {
      expect(await detectLicensesInDir('.'), [new License('BSD')]);
      await expectFile('test/licenses/bsd_2_clause.txt', new License('BSD'));
      await expectFile('test/licenses/bsd_3_clause.txt', new License('BSD'));
      await expectFile('test/licenses/bsd_revised.txt', new License('BSD'));
    });
  });

  group('GPL', () {
    test('explicit', () async {
      expect(
          detectLicenseInContent([
            'GNU GENERAL PUBLIC LICENSE',
            'Version 2, June 1991'
          ].join('\n')),
          new License('GPL', '2.0'));
      expect(detectLicenseInContent(['GNU GPL Version 2'].join('\n')),
          new License('GPL', '2.0'));
      await expectFile('test/licenses/gpl_v3.txt', new License('GPL', '3.0'));
    });
  });

  group('LGPL', () {
    test('explicit', () async {
      expect(
          detectLicenseInContent(
              '\nGNU LESSER GENERAL PUBLIC LICENSE\n    Version 3, 29 June 2007'),
          new License('LGPL', '3.0'));
      await expectFile('test/licenses/lgpl_v3.txt', new License('LGPL', '3.0'));
    });
  });

  group('MIT', () {
    test('explicit', () async {
      expect(detectLicenseInContent('\n\n   The MIT license\n\n blah...'),
          new License('MIT'));
      expect(detectLicenseInContent('MIT license\n\n blah...'),
          new License('MIT'));
      await expectFile('test/licenses/mit.txt', new License('MIT'));
    });
  });

  group('MPL', () {
    test('explicit', () async {
      expect(
          detectLicenseInContent(
              '\n\n   Mozilla Public License Version 2.0\n\n blah...'),
          new License('MPL', '2.0'));
      await expectFile('test/licenses/mpl_v2.txt', new License('MPL', '2.0'));
    });
  });

  group('Unlicense', () {
    test('explicit', () async {
      expect(
          detectLicenseInContent(
              '\n\n   This is free and unencumbered software released into the public domain.\n'),
          new License('Unlicense'));
      await expectFile('test/licenses/unlicense.txt', new License('Unlicense'));
    });
  });

  group('unknown', () {
    test('empty content', () {
      expect(detectLicenseInContent(''), isNull);
    });
  });
}
