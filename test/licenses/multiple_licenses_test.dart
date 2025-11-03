// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/license.dart';
import 'package:test/test.dart';

void main() {
  group('Multiple licenses in the same file', () {
    test('Licenses separated by comments', () async {
      // Note: this kind of license is only suggested by LLMs for now.
      final input = File(
        'test/licenses/multiple_licenses_comments.txt',
      ).readAsStringSync();

      final detected = await detectLicenseInContent(input);
      expect(detected.map((l) => l.toJson()).toList(), [
        {
          'spdxIdentifier': 'Apache-2.0',
          'operations': [1, 1569, 11323],
        },
        {
          'spdxIdentifier': 'BSD-2-Clause',
          'operations': [
            0,
            240,
            28,
            'Copyright (c) <year> <owner>',
            1,
            240,
            1239,
          ],
        },
      ]);
    });

    test('Licenses separated by sections', () async {
      // Note: this kind of license is only suggested by LLMs for now.
      final input = File(
        'test/licenses/multiple_licenses_sections.txt',
      ).readAsStringSync();

      final detected = await detectLicenseInContent(input);
      expect(detected.map((l) => l.toJson()).toList(), [
        {
          'spdxIdentifier': 'Apache-2.0',
          'operations': [1, 1441, 11323],
        },
        {
          'spdxIdentifier': 'BSD-2-Clause',
          'operations': [
            0,
            134,
            28,
            'Copyright (c) <year> <owner>',
            1,
            134,
            1239,
          ],
        },
      ]);
    });

    test('Licenses separated by dashes', () async {
      // Testing a LICENSE file with Flutter-like separation, similar to the
      // description of https://api.flutter.dev/flutter/foundation/LicenseRegistry-class.html
      //
      //     The flutter tool will automatically collect the contents of all the LICENSE files
      //     found at the root of each package into a single LICENSE file in the default asset
      //     bundle. Each license in that file is separated from the next by a line of eighty
      //     hyphens (-), and begins with a list of package names that the license applies to,
      //     one to a line, separated from the next by a blank line.
      final input = File(
        'test/licenses/multiple_licenses_allnotifications.txt',
      ).readAsStringSync();

      final detected = await detectLicenseInContent(input);
      expect(detected.map((l) => l.toJson()).toList(), [
        {
          'spdxIdentifier': 'BSD-3-Clause',
          'operations': [
            0,
            1215,
            29,
            'Copyright (c) <year> <owner>.',
            1,
            1215,
            1430,
          ],
        },
        {
          'spdxIdentifier': 'MIT',
          'operations': [
            0,
            31,
            53,
            'MIT License\n\nCopyright (c) <year> <copyright holders>',
            1,
            31,
            1022,
          ],
        },
      ]);
    });

    test('Licenses without separation', () async {
      final input = File(
        'test/licenses/multiple_licenses_pikaday_datepicker.txt',
      ).readAsStringSync();
      final detected = await detectLicenseInContent(input);
      expect(detected.map((l) => l.toJson()).toList(), [
        {
          'spdxIdentifier': 'BSD-2-Clause',
          'operations': [
            0,
            1276,
            28,
            'Copyright (c) <year> <owner>',
            1,
            1276,
            1235,
          ],
        },
        {
          'spdxIdentifier': 'MIT',
          'operations': [
            0,
            213,
            53,
            'MIT License\n\nCopyright (c) <year> <copyright holders>',
            1,
            213,
            1022,
          ],
        },
      ]);
    });
  });
}
