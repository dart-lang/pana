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

      final detected = await detectLicenseInContent(
        input,
        relativePath: 'LICENSE',
      );
      expect(detected.map((l) => l.toJson()).toList(), [
        {
          'path': 'LICENSE',
          'spdxIdentifier': 'Apache-2.0',
          'range': {
            'start': {'offset': 1569, 'line': 33, 'column': 33},
            'end': {'offset': 12892, 'line': 233, 'column': 33},
            'coverages': [1569, 12892],
          },
        },
        {
          'path': 'LICENSE',
          'spdxIdentifier': 'BSD-2-Clause',
          'range': {
            'start': {'offset': 240, 'line': 8, 'column': 0},
            'end': {'offset': 1479, 'line': 27, 'column': 68},
            'coverages': [240, 1479],
          },
        },
      ]);
    });

    test('Licenses separated by sections', () async {
      // Note: this kind of license is only suggested by LLMs for now.
      final input = File(
        'test/licenses/multiple_licenses_sections.txt',
      ).readAsStringSync();

      final detected = await detectLicenseInContent(
        input,
        relativePath: 'LICENSE',
      );
      expect(detected.map((l) => l.toJson()).toList(), [
        {
          'path': 'LICENSE',
          'spdxIdentifier': 'Apache-2.0',
          'range': {
            'start': {'offset': 1441, 'line': 30, 'column': 33},
            'end': {'offset': 12764, 'line': 230, 'column': 33},
            'coverages': [1441, 12764],
          },
        },
        {
          'path': 'LICENSE',
          'spdxIdentifier': 'BSD-2-Clause',
          'range': {
            'start': {'offset': 134, 'line': 7, 'column': 0},
            'end': {'offset': 1373, 'line': 26, 'column': 68},
            'coverages': [134, 1373],
          },
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

      final detected = await detectLicenseInContent(
        input,
        relativePath: 'LICENSE',
      );
      expect(detected.map((l) => l.toJson()).toList(), [
        {
          'path': 'LICENSE',
          'spdxIdentifier': 'BSD-3-Clause',
          'range': {
            'start': {'offset': 1215, 'line': 28, 'column': 0},
            'end': {'offset': 2645, 'line': 52, 'column': 68},
            'coverages': [1215, 2645],
          },
        },
        {
          'path': 'LICENSE',
          'spdxIdentifier': 'MIT',
          'range': {
            'start': {'offset': 31, 'line': 5, 'column': 0},
            'end': {'offset': 1053, 'line': 21, 'column': 9},
            'coverages': [31, 1053],
          },
        },
      ]);
    });

    test('Licenses without separation', () async {
      final input = File(
        'test/licenses/multiple_licenses_pikaday_datepicker.txt',
      ).readAsStringSync();
      final detected = await detectLicenseInContent(
        input,
        relativePath: 'LICENSE',
      );
      expect(detected.map((l) => l.toJson()).toList(), [
        {
          'path': 'LICENSE',
          'spdxIdentifier': 'BSD-2-Clause',
          'range': {
            'start': {'offset': 1276, 'line': 30, 'column': 0},
            'end': {'offset': 2511, 'line': 36, 'column': 755},
            'coverages': isNotEmpty,
          },
        },
        {
          'path': 'LICENSE',
          'spdxIdentifier': 'MIT',
          'range': {
            'start': {'offset': 213, 'line': 8, 'column': 0},
            'end': {'offset': 1235, 'line': 24, 'column': 13},
            'coverages': isNotEmpty,
          },
        },
      ]);
    });
  });
}
