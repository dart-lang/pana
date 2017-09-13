// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:pana/src/license.dart';

main() {
  group('AGPL', () {
    test('explicit', () {
      expect(detectLicenseInContent('GNU AFFERO GENERAL PUBLIC LICENSE'),
          new License('AGPL'));
    });
  });

  group('Apache', () {
    test('explicit', () {
      expect(
          detectLicenseInContent(
              '   Apache License\n     Version 2.0, January 2004\n'),
          new License('Apache', '2.0'));
    });
  });

  group('BSD', () {
    test('detect project LICENSE', () async {
      expect(await detectLicenseInDir('.'), new License('BSD'));
    });
  });

  group('GPL', () {
    test('explicit', () {
      expect(
          detectLicenseInContent([
            'GNU GENERAL PUBLIC LICENSE',
            'Version 2, June 1991'
          ].join('\n')),
          new License('GPL', '2.0'));
      expect(detectLicenseInContent(['GNU GPL Version 2'].join('\n')),
          new License('GPL', '2.0'));
    });
  });

  group('LGPL', () {
    test('explicit', () {
      expect(
          detectLicenseInContent(
              '\nGNU LESSER GENERAL PUBLIC LICENSE\n    Version 3, 29 June 2007'),
          new License('LGPL', '3.0'));
    });
  });

  group('MIT', () {
    test('explicit', () {
      expect(detectLicenseInContent('\n\n   The MIT license\n\n blah...'),
          new License('MIT'));
      expect(detectLicenseInContent('MIT license\n\n blah...'),
          new License('MIT'));
    });
  });

  group('MPL', () {
    test('explicit', () {
      expect(
          detectLicenseInContent(
              '\n\n   Mozilla Public License Version 2.0\n\n blah...'),
          new License('MPL', '2.0'));
    });
  });

  group('Unlicense', () {
    test('explicit', () {
      expect(
          detectLicenseInContent(
              '\n\n   This is free and unencumbered software released into the public domain.\n'),
          new License('Unlicense'));
    });
  });

  group('unknown', () {
    test('empty content', () {
      expect(detectLicenseInContent(''), isNull);
    });
  });
}
