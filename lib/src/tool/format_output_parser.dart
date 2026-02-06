// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../utils.dart';
import 'run_constrained.dart';

/// Parses the output of `dart format` and returns the list of files
/// (relative to the [packageDir]) that need formatting.
///
/// Throws [ToolException] if the output is ambigious.
List<String> parseDartFormatOutput({
  required String packageDir,
  required int exitCode,
  required String output,
  PanaProcessResult? result,
}) {
  final dirPrefix = '${p.normalize(packageDir)}/';
  final lines = LineSplitter.split(output).toList();
  final changedFiles =
      lines
          .where((l) => l.startsWith('Changed'))
          .map((l) => l.substring(8).replaceFirst(dirPrefix, '').trim())
          .where(isAnalysisTarget)
          .toList()
        ..sort();

  // clean exit of `dart format` with code = 1
  // it should report at least one changed file
  if (exitCode == 1 && changedFiles.isNotEmpty) {
    return changedFiles;
  }
  // unclear exit, trying to retain only unexpected lines:
  final unexpectedLines = lines
      .where((l) => l.isNotEmpty)
      // regular output
      .whereNot((l) => l.startsWith('Changed') || l.startsWith('Formatted'))
      // reference resolve warnings, can be ignored
      .whereNot(
        (l) =>
            l.startsWith('Warning: Package resolution error') ||
            l.startsWith('Failed to resolve package URI'),
      )
      // Issue with the format of the file, line can be ignored, details with be repeated later
      .whereNot(
        (l) => l.startsWith(
          'Could not format because the source could not be parsed',
        ),
      )
      // parse lines like `line 142, column 21 of /tmp/pana_CAMRUS/example/lib/main.dart: This requires the 'null-aware-elements' language feature to be enabled.`
      .whereNot((l) {
        if (!l.startsWith('line ')) return false;
        final path = RegExp(
          r'^line \d+, column \d+ of (/.+)\:',
        ).matchAsPrefix(l)?.group(1)?.replaceFirst(dirPrefix, '');
        if (path == null) return false;
        if (isAnalysisTarget(path)) {
          // keeping the line, since it may be important
          return false;
        } else {
          // file is outside of the scope of analysis, e.g. `example/lib/main.dart`
          return true;
        }
      })
      // code example with line number prefix (e.g. ` <number> |`), can be ignored
      .whereNot((l) => l.startsWith(RegExp(r'\s*\d*\s*[\|╷╵│]')))
      .toList();

  // all output lines are known and can be ignored
  if (unexpectedLines.isEmpty) {
    return changedFiles;
  }

  final errorMsg = LineSplitter.split(output).take(20).join('\n');
  throw ToolException(errorMsg, result);
}
