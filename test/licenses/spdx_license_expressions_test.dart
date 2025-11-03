// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license.dart';
import 'package:test/test.dart';

void main() {
  // TODO: Implement detecting SPDX license expressions as described in
  //       https://spdx.github.io/spdx-spec/v2.3/SPDX-license-expressions/
  group('SPDX license expressions', () {
    test('Simple expression', () async {
      final detected = await detectLicenseInContent('BSD-3-Clause');
      // TODO: update detection and report the matched license
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });

    test('Complex expression', () async {
      final detected = await detectLicenseInContent('MIT OR BSD-3-Clause');
      // TODO: update detection and report the matched licenses
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });
  });
}
