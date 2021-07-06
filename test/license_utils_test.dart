// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

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
    final licenses = loadLicensesFromDirectories(['test/license_test_assets']);
    const licenseNames = [
      'agpl_v3',
      'agpl_v3',
      'apache_v2',
      'apache_v2',
      'bsd_2_clause',
      'bsd_2_clause_in_comments',
      'bsd_3_clause'
    ];

    expect(licenses.length, 7);

    for (var i = 0; i < 7; i++) {
      expect(licenses[i].identifier, licenseNames[i]);
    }
  });

  // test('Test checksum generation', () {
  //   final text = 'generate some checksums for these tokens';
  //   final expected = [202247124, 3226558818, 1391268045, 1050691930];
  //   final actual = generateChecksums(tokenize(text));

  //   expect(actual.length, expected.length);

  //   for (var i = 0; i < actual.length; i++) {
  //     expect(actual[i].crc32, expected[i]);
  //   }
  // });
}
