// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/tool/format_output_parser.dart';
import 'package:pana/src/tool/run_constrained.dart';
import 'package:test/test.dart';

void main() {
  group('parsing known output', () {
    test('empty output', () {
      final list = parseDartFormatOutput(
        packageDir: '/tmp/x',
        exitCode: 0,
        output: '',
      );
      expect(list, isEmpty);
    });

    test('some files need updating (regular output, relative path)', () {
      final list = parseDartFormatOutput(
        packageDir: '/tmp/x',
        exitCode: 1,
        output:
            'Changed lib/unformatted.dart\n'
            'Formatted 130 files (1 changed) in 0.35 seconds.',
      );
      expect(list, ['lib/unformatted.dart']);
    });

    test('some files need updating (regular output, absolute path)', () {
      final list = parseDartFormatOutput(
        packageDir: '/tmp/x',
        exitCode: 1,
        output:
            'Changed /tmp/x/lib/unformatted.dart\n'
            'Formatted 130 files (1 changed) in 0.35 seconds.',
      );
      expect(list, ['lib/unformatted.dart']);
    });

    test('some files need updating (regular output, absolute path)', () {
      final list = parseDartFormatOutput(
        packageDir: '/tmp/x',
        exitCode: 1,
        output:
            'Changed /tmp/x/lib/unformatted.dart\n'
            'Formatted 130 files (1 changed) in 0.35 seconds.',
      );
      expect(list, ['lib/unformatted.dart']);
    });

    test('example directory is not parsed', () {
      final list = parseDartFormatOutput(
        packageDir: '/tmp/pana_ZVVKSB',
        exitCode: -1,
        output: '''Changed /tmp/pana_ZVVKSB/example/lib/components/menu.dart
Formatted 32 files (1 changed) in 0.04 seconds.
Warning: Package resolution error when reading "analysis_options.yaml" file:
Failed to resolve package URI "package:flutter_lints/flutter.yaml" in include.
Warning: Package resolution error when reading "analysis_options.yaml" file:
Failed to resolve package URI "package:flutter_lints/flutter.yaml" in include.
Could not format because the source could not be parsed:

line 142, column 21 of /tmp/pana_ZVVKSB/example/lib/main.dart: This requires the 'null-aware-elements' language feature to be enabled.
    ╷
142 │           strokes: [?controller.currentStroke],
    │                     ^
    ╵
Warning: Package resolution error when reading "analysis_options.yaml" file:
Failed to resolve package URI "package:flutter_lints/flutter.yaml" in include.''',
      );
      expect(list, isEmpty);
    });

    test('Unexpected output', () {
      expect(
        () => parseDartFormatOutput(
          packageDir: '/tmp/x',
          exitCode: 1,
          output: 'Could not find directory.',
        ),
        throwsA(isA<ToolException>()),
      );
    });
  });
}
