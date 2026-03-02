// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:pana/src/tag/_common.dart';
import 'package:pana/src/tag/safe_imports.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('isSafeImport', () {
    test('returns true for safe dart:io symbols only', () async {
      final directive = await _parseDirective(
        "import 'dart:io' show HttpStatus;",
      );
      expect(isSafeImport(directive, Uri.parse('dart:io')), isTrue);
    });

    test('returns true for multiple safe dart:io symbols', () async {
      final directive = await _parseDirective(
        "import 'dart:io' show HttpStatus, HttpHeaders, HttpDate;",
      );
      expect(isSafeImport(directive, Uri.parse('dart:io')), isTrue);
    });

    test('returns false for unsafe dart:io symbols', () async {
      final directive = await _parseDirective("import 'dart:io' show File;");
      expect(isSafeImport(directive, Uri.parse('dart:io')), isFalse);
    });

    test('returns false for mixed safe and unsafe symbols', () async {
      final directive = await _parseDirective(
        "import 'dart:io' show HttpStatus, File;",
      );
      expect(isSafeImport(directive, Uri.parse('dart:io')), isFalse);
    });

    test('returns false for import without show clause', () async {
      final directive = await _parseDirective("import 'dart:io';");
      expect(isSafeImport(directive, Uri.parse('dart:io')), isFalse);
    });

    test('returns false for import with hide clause', () async {
      final directive = await _parseDirective("import 'dart:io' hide File;");
      expect(isSafeImport(directive, Uri.parse('dart:io')), isFalse);
    });

    test('returns false for import with both show and hide clauses', () async {
      final directive = await _parseDirective(
        "import 'dart:io' show HttpStatus hide File;",
      );
      expect(isSafeImport(directive, Uri.parse('dart:io')), isFalse);
    });

    test('returns false for unspecified libraries', () async {
      final directive = await _parseDirective(
        "import 'dart:html' show Window;",
      );
      expect(isSafeImport(directive, Uri.parse('dart:html')), isFalse);
    });

    test('returns false for package imports', () async {
      final directive = await _parseDirective(
        "import 'package:http/http.dart' show Client;",
      );
      expect(
        isSafeImport(directive, Uri.parse('package:http/http.dart')),
        isFalse,
      );
    });

    test('works with export directives', () async {
      final directive = await _parseDirective(
        "export 'dart:io' show HttpStatus;",
      );
      expect(isSafeImport(directive, Uri.parse('dart:io')), isTrue);
    });

    test('returns false for export without show clause', () async {
      final directive = await _parseDirective("export 'dart:io';");
      expect(isSafeImport(directive, Uri.parse('dart:io')), isFalse);
    });

    test('handles multiple show combinators (union)', () async {
      // Note: This syntax is unusual but valid in Dart
      final directive = await _parseDirective(
        "import 'dart:io' show HttpStatus show HttpHeaders;",
      );
      expect(isSafeImport(directive, Uri.parse('dart:io')), isTrue);
    });

    test(
      'returns false for multiple show combinators with unsafe symbol',
      () async {
        final directive = await _parseDirective(
          "import 'dart:io' show HttpStatus show File;",
        );
        expect(isSafeImport(directive, Uri.parse('dart:io')), isFalse);
      },
    );
  });
}

/// Parses the [code] and returns the first namespace directive.
Future<NamespaceDirective> _parseDirective(String code) async {
  return await withTempDir((tempDir) async {
    final testFile = path.join(tempDir, 'test.dart');
    await File(testFile).writeAsString(code);

    final collection = AnalysisContextCollection(includedPaths: [tempDir]);
    final session = collection.contextFor(tempDir).currentSession;
    final fileUri = Uri.file(testFile);
    final unit = parsedUnitFromUri(session, fileUri);

    return unit!.directives.whereType<NamespaceDirective>().first;
  });
}
