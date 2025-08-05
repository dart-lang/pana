// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/license.dart';
import 'package:test/test.dart';

void main() {
  group('Complex license texts', () {
    test('as-is with a lot of contributors', () async {
      // License text is from package:html
      final input =
          File('test/licenses/as_is_with_contributors.txt').readAsStringSync();

      final detected =
          await detectLicenseInContent(input, relativePath: 'LICENSE');
      // TODO: update detection and report the as-is license
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });

    test('commercial with limited free-use', () async {
      // License text is from package:scanbot_sdk
      final input = File('test/licenses/commercial_with_limited_free_use.txt')
          .readAsStringSync();

      final detected =
          await detectLicenseInContent(input, relativePath: 'LICENSE');
      // TODO: update detection and report the commercial license
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });

    test('short version of Apache V2', () async {
      // License text is from package:latlong2
      final input =
          File('test/licenses/apache_v2_short.txt').readAsStringSync();

      final detected =
          await detectLicenseInContent(input, relativePath: 'LICENSE');
      // TODO: update detection and report the apache license
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });

    test('modified version of MIT (changes unknown)', () async {
      // License text is from package:onesignal_flutter
      final input = File('test/licenses/modified_mit.txt').readAsStringSync();

      final detected =
          await detectLicenseInContent(input, relativePath: 'LICENSE');
      // TODO: update detection and report the MIT license + its modifications
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });

    test('CC0 Universal', () async {
      // License text is from package:simple_icons
      final input = File('test/licenses/cc0_universal.txt').readAsStringSync();

      final detected =
          await detectLicenseInContent(input, relativePath: 'LICENSE');
      // TODO: update detection and report the CC0 license
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });

    test('GPL v2 with extra content', () async {
      // License text is from package:fuzzywuzzy
      final input =
          File('test/licenses/gpl_v2_with_extras.txt').readAsStringSync();

      final detected =
          await detectLicenseInContent(input, relativePath: 'LICENSE');
      // TODO: update detection and report the GPL v2 license + the extras separately
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });

    test('Custom, non-free license with restrictions', () async {
      // License text is from package:non_free_i18n_extension
      final input =
          File('test/licenses/non_free_i18n_extension.txt').readAsStringSync();

      final detected =
          await detectLicenseInContent(input, relativePath: 'LICENSE');
      // TODO: update detection and report the non-free parts
      expect(detected.map((l) => l.toJson()).toList(), <Map>[]);
    });
  });
}
