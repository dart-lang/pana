// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license.dart';
import 'package:pana/src/license_detection/license_detector.dart';
import 'package:test/test.dart';

void main() {
  group('License coverage', () {
    test('Coverage of all reference text', () async {
      final allLicenses = await listDefaultLicenses();
      expect(allLicenses, hasLength(greaterThan(30)));
      for (final license in allLicenses) {
        final detected = await detectLicenseInContent(
          license.content,
          relativePath: 'LICENSE',
        );
        // should only match the same license
        expect(detected, hasLength(1));
        final match = detected.single;
        expect(match.spdxIdentifier, license.identifier);
        expect(match.operations!, hasLength(1));
      }
    });
  });
}
