// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

import 'internal_model.dart';
import 'tool/run_constrained.dart' show ToolException;

// ignore: prefer_interpolation_to_compose_strings
final _regexp = RegExp([
  '^', // beginning of line
  '([\\w_\\.]+)\\|' * 3, // first three error notes
  '([^\\|]+)\\|', // file path
  '([\\w_\\.]+)\\|' * 3, // line, column, length
  '(.*?)', // rest is the error message
  '\$', // end of line
].join());

CodeProblem? parseCodeProblem(String content, {String? projectDir}) {
  if (content.isEmpty) {
    return null;
  }
  var matches = _regexp.allMatches(content).toList();

  if (matches.isEmpty) {
    if (content.endsWith(' is a part and cannot be analyzed.')) {
      var filePath = content.split(' ').first;

      content = content.replaceAll(filePath, '').trim();

      if (projectDir != null) {
        assert(p.isWithin(projectDir, filePath));
        filePath = p.relative(filePath, from: projectDir);
      }

      return CodeProblem(
        severity: 'ERROR',
        errorType: 'ANALYSIS',
        errorCode: 'UNKNOWN',
        description: content,
        file: filePath,
        line: 0,
        col: 0,
        length: 0,
      );
    }

    if (content == 'Please pass in a library that contains this part.') {
      return null;
    }

    if (content.startsWith('STDERR exceeded') && content.endsWith(' lines.')) {
      return CodeProblem(
        severity: 'ERROR',
        errorType: 'ANALYSIS',
        errorCode: 'TOO_MANY_LINES',
        description: 'Analysis returned too many issues.',
        file: 'pubspec.yaml',
        line: 0,
        col: 0,
        length: 0,
      );
    }

    throw ToolException(
        'Analysis failed with unexpected output.\n`$content`', null);
  }

  var match = matches.single;

  var severity = match[1];
  var errorType = match[2];
  var errorCode = match[3];

  var filePath = match[4];
  var line = match[5];
  var column = match[6];
  var length = match[7];
  var description = match[8];

  // `dart analyze --format=machine` returns backslashes escaped with double backslash
  filePath = filePath!.replaceAll(r'\\', r'\');

  if (projectDir != null) {
    assert(p.isWithin(projectDir, filePath));
    filePath = p.relative(filePath, from: projectDir);
  }

  return CodeProblem(
    severity: severity!,
    errorType: errorType!,
    errorCode: errorCode!,
    description: description!,
    file: filePath,
    line: int.parse(line!),
    col: int.parse(column!),
    length: int.parse(length!),
  );
}
