// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

/// This tests loads the library specification of the Dart SDK and tests if
/// all of them are mentioned in `lib/src/tag/_specs.dart`.
void main() {
  test('Dart SDK libraries exist in _specs.dart', () async {
    final rs = await get(
      Uri.parse(
        'https://raw.githubusercontent.com/dart-lang/sdk/main/sdk/lib/libraries.json',
      ),
    );
    expect(rs.statusCode, 200);
    final parsed = json.decode(rs.body) as Map;
    final allLibraries = <String>{};
    for (final topLevel in parsed.entries) {
      final tlv = topLevel.value;
      if (tlv is! Map) {
        continue;
      }
      final libraries = tlv['libraries'];
      if (libraries is Map) {
        allLibraries.addAll(libraries.keys.whereType<String>());
      }
    }
    final publicLibraries = allLibraries
        .where((e) => !e.startsWith('_'))
        .toList();

    final exempted = {'concurrent', 'vmservice', 'vmservice_io'};
    final specContent = await File('lib/src/tag/_specs.dart').readAsString();
    for (final lib in publicLibraries) {
      if (exempted.contains(lib)) {
        continue;
      }
      expect(specContent, contains("'$lib'"));
    }
  });
}
