// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:io/io.dart';
import 'package:test/test.dart';

import 'golden_file.dart';

void main() {
  // This is really two tests in one, because the second one depends on the
  // golden file from the first.
  testWithGolden(
    'run with bad option shows help text. Help text is included in readme ',
    (goldenContext) async {
      final readme = File('README.md').readAsStringSync();
      final helpText = RegExp(
        r'```\n(Usage:.*)\n```',
        multiLine: true,
        dotAll: true,
      ).firstMatch(readme)![1]!;
      await goldenContext.run(
        [Platform.resolvedExecutable, 'run', 'pana', '--monkey'],
        stdoutExpectation: allOf(
          contains('Could not find an option named "--monkey".\n\n'),
          contains(helpText),
        ),
        exitCodeExpectation: ExitCode.usage.code,
      );
    },
  );
}
