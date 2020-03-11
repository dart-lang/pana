// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.code_problem;

import 'package:path/path.dart' as p;

import 'model.dart';

final _regexp = RegExp('^' + // beginning of line
        '([\\w_\\.]+)\\|' * 3 + // first three error notes
        '([^\\|]+)\\|' + // file path
        '([\\w_\\.]+)\\|' * 3 + // line, column, length
        '(.*?)' + // rest is the error message
        '\$' // end of line
    );

CodeProblem parseCodeProblem(String content, {String projectDir}) {
  if (content.isEmpty) {
    throw ArgumentError('Provided content is empty.');
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
        severity: 'WEIRD',
        errorType: 'UNKNOWN',
        errorCode: 'UNKNOWN',
        description: content,
        file: filePath,
        line: 0,
        col: 0,
      );
    }

    if (content == 'Please pass in a library that contains this part.') {
      return null;
    }

    throw ArgumentError(
        'Provided content does not align with expectations.\n`$content`');
  }

  var match = matches.single;

  var severity = match[1];
  var errorType = match[2];
  var errorCode = match[3];

  var filePath = match[4];
  var line = match[5];
  var column = match[6];
  // length = 7
  var description = match[8];

  // dartanalyzer --format=machine returns backslashes escaped with double backslash
  filePath = filePath.replaceAll(r'\\', r'\');

  if (projectDir != null) {
    assert(p.isWithin(projectDir, filePath));
    filePath = p.relative(filePath, from: projectDir);
  }

  return CodeProblem(
    severity: severity,
    errorType: errorType,
    errorCode: errorCode,
    description: description,
    file: filePath,
    line: int.parse(line),
    col: int.parse(column),
  );
}
