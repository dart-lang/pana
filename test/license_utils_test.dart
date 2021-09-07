// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license_detector.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

void main() {
  test('Test frequency table', () {
    final text = 'some text to t-o generate table ta%^&*ble';
    var expected = <String, int>{
      'some': 1,
      'text': 1,
      'to': 2,
      'generate': 1,
      'table': 2,
    };
    final actual = generateFrequencyTable(tokenize(text));

    actual.forEach((key, value) {
      expect(value, expected[key]);
    });
  });

  test('Load licenses from directory', () {
    final licenses =
        loadLicensesFromDirectories(['test/license_test_assets/licenses']);
    const licenseNames = [
      'agpl_v3',
      'agpl_v3',
      'apache_v2',
      'apache_v2',
      'bsd_2_clause',
      'bsd_2_clause_in_comments',
      'bsd_3_clause',
    ];

    expect(licenses.length, 7);

    for (var i = 0; i < 7; i++) {
      expect(licenses[i].identifier, licenseNames[i]);
    }

    expect(() => loadLicensesFromDirectories(['test/license_test_assets/']),
        throwsFormatException);
  });

  test('Test checksum generation', () {
    final text = 'generate some checksums for these tokens';
    final expected = [3898316725, 3188174184, 1984569744, 820879958];
    final ranges = [Range(0, 3), Range(1, 4), Range(2, 5), Range(3, 6)];
    final actual = generateChecksums(tokenize(text), 3);

    expect(actual.length, expected.length);

    for (var i = 0; i < actual.length; i++) {
      expect(actual[i].checksum, expected[i]);
      expect(actual[i].start, ranges[i].start);
      expect(actual[i].end, ranges[i].end);
    }
  });

  test('Tokens normalized value', () {
    final str = 'Here is some text for testing purposes';

    final tokens = tokenize(str);

    expect(normalizedContent(tokens), 'here is some text for testing purposes');
  });

  test('generateChecksumMap test', () {
    final text = 'generate some checksums for these tokens';
    final expected = {
      3898316725: 1,
      3188174184: 1,
      1984569744: 1,
      820879958: 1
    };

    final actual = generateChecksumMap(generateChecksums(tokenize(text), 3));

    expect(actual.length, expected.length);

    actual.forEach((key, value) {
      expect(value.length, expected[key]!);
      expect(key, value[0].checksum);
    });
  });
}
