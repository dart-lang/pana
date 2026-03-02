// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/tag/pana_tags.dart';
import 'package:pana/src/tag/tagger.dart';
import 'package:pana/src/tool/run_constrained.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Safe imports end2end', () {
    test('package with safe symbols is wasm-ready', () async {
      await withTempDir((tempDir) async {
        await _createAndInitTestPackage(
          tempDir,
          "import 'dart:io' show HttpStatus, HttpHeaders, HttpDate;\n\nclass MyClass {}\n",
        );

        final tagger = Tagger(tempDir);
        final tags = <String>[];
        final explanations = <Explanation>[];

        tagger.wasmReadyTag(tags, explanations);
        expect(tags, contains(PanaTags.isWasmReady));
        expect(
          explanations.where((e) => e.tag == PanaTags.isWasmReady),
          isEmpty,
        );

        tagger.platformTags(tags, explanations);
        expect(tags, contains(PanaTags.platformWeb));
      });
    });

    test('package with unsafe File import is not wasm-ready', () async {
      await withTempDir((tempDir) async {
        await _createAndInitTestPackage(
          tempDir,
          "import 'dart:io' show File;\n\nclass MyClass {}\n",
        );

        final tagger = Tagger(tempDir);
        final tags = <String>[];
        final explanations = <Explanation>[];

        tagger.wasmReadyTag(tags, explanations);
        expect(tags, isNot(contains(PanaTags.isWasmReady)));
        expect(
          explanations.where((e) => e.tag == PanaTags.isWasmReady),
          isNotEmpty,
          reason: 'Should have violation for unsafe File import',
        );

        tagger.platformTags(tags, explanations);
        expect(tags, isNot(contains(PanaTags.platformWeb)));
      });
    });
  });
}

Future<void> _createAndInitTestPackage(
  String packageDir,
  String libraryCode,
) async {
  final libDir = Directory(p.join(packageDir, 'lib'));
  await libDir.create(recursive: true);

  final pubspecContent = '''name: foo
publish_to: none
environment:
  sdk: '>=3.0.0 <4.0.0'
''';
  await File(p.join(packageDir, 'pubspec.yaml')).writeAsString(pubspecContent);

  await File(p.join(libDir.path, 'foo.dart')).writeAsString(libraryCode);

  await runConstrained(
    ['dart', 'pub', 'get'],
    workingDirectory: packageDir,
    throwOnError: true,
  );
}
