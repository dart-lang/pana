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

  group('MIT', () {
    test('explicit', () {
      expect(detectLicenseInContent('\n\n   The MIT license\n\n blah...'),
          new License('MIT'));
    });
  });

  group('unknown', () {
    test('empty content', () {
      expect(detectLicenseInContent(''), isNull);
    });
  });
}
