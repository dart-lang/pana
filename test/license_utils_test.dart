// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/src/license_detection/license_detector.dart';
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
    final licenses = loadLicensesFromDirectories([
      'test/license_test_assets/licenses',
    ]);
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

    expect(
      () => loadLicensesFromDirectories(['test/license_test_assets/']),
      throwsFormatException,
    );
  });

  test('decodeCompressedLicenses matches loadLicensesFromDirectories', () {
    final fromDir = loadLicensesFromDirectories([
      'test/license_test_assets/licenses',
    ]);
    final files =
        Directory('test/license_test_assets/licenses')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.txt'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final licenseTexts = <String, String>{
      for (final file in files)
        file.uri.pathSegments.last.split('.txt').first: file
            .readAsStringSync()
            .replaceAll('\r\n', '\n'),
    };
    final compressed = zlib.encode(utf8.encode(json.encode(licenseTexts)));
    final fromCompressed = decodeCompressedLicenses(compressed);
    expect(fromCompressed.length, fromDir.length);
    for (var i = 0; i < fromDir.length; i++) {
      expect(fromCompressed[i].identifier, fromDir[i].identifier);
      expect(fromCompressed[i].content, fromDir[i].content);
    }
  });

  test('Tokens normalized value', () {
    final str = 'Here is some text for testing purposes';

    final tokens = tokenize(str);

    expect(normalizedContent(tokens), 'here is some text for testing purposes');
  });
}
