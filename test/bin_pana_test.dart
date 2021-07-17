// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:io/io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

import 'golden_file.dart';

final helpGoldenPath = p.join('test', 'goldens', 'help.txt');

void main() {
  // This is really two tests in one, because the second one depends on the
  // golden file from the first.
  test('run with bad option shows help text. Help text is included in readme ',
      () async {
    var process = await TestProcess.start(
        p.join(p.dirname(Platform.resolvedExecutable),
            Platform.isWindows ? 'pub.bat' : 'pub'),
        ['run', 'pana', '--monkey']);

    var output = await process.stdoutStream().join('\n');

    const prefix = 'Could not find an option named "monkey".\n\n';

    expect(output, startsWith(prefix));
    expectMatchesGoldenFile(output.substring(prefix.length), helpGoldenPath);

    await process.shouldExit(ExitCode.usage.code);

    var readme = File('README.md');
    expect(readme.readAsStringSync().replaceAll('\r\n', '\n'),
        contains('```\n${File(helpGoldenPath).readAsStringSync().replaceAll('\r\n', '\n')}\n```'));
  });
}
