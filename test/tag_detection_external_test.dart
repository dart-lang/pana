// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart';
import 'package:pana/src/tag_detection.dart';
import 'package:test/test.dart';

void main() {
  group('Dart SDK library definitions', () {
    Map<String, dynamic> libraries;
    Set<String> allVmLibs;
    Set<String> publicVmLibs;
    Set<String> allDart2jsLibs;
    Set<String> publicDart2jsLibs;

    Set<String> extractLibraries(Map<String, dynamic> map) {
      return map.entries
          .where(
              (e) => e.value is Map && (e.value as Map)['supported'] != false)
          .map((e) => e.key)
          .toSet();
    }

    setUpAll(() async {
      // Download and parse https://github.com/dart-lang/sdk/blob/master/sdk/lib/libraries.json
      final librariesContent = await get(
          'https://raw.githubusercontent.com/dart-lang/sdk/master/sdk/lib/libraries.json');
      libraries = json.decode(librariesContent.body) as Map<String, dynamic>;
      allVmLibs = extractLibraries(
          libraries['vm']['libraries'] as Map<String, dynamic>);
      publicVmLibs = allVmLibs.where((s) => !s.startsWith('_')).toSet();
      allDart2jsLibs = extractLibraries(
          libraries['dart2js']['libraries'] as Map<String, dynamic>);
      publicDart2jsLibs =
          allDart2jsLibs.where((s) => !s.startsWith('_')).toSet();
    });

    test('VM libraries', () {
      for (final lib in publicVmLibs) {
        if (lib == 'wasm' || lib == 'vmservice_io') {
          continue; // ignore for now
        }
        expect(Runtime.nativeJit.enabledLibs, contains(lib));
      }
    });

    test('dart2js libraries', () {
      for (final lib in publicDart2jsLibs) {
        expect(Runtime.web.enabledLibs, contains(lib));
      }
    });
  });
}
