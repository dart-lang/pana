// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/src/sandbox_runner.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SandboxRunner', () {
    test(
      'sets both SANDBOX_OUTPUT_JSON and SANDBOX_OUTPUT when no colons',
      () async {
        await withTempDir((dir) async {
          final script = File(p.join(dir, 'print_env.dart'));
          await script.writeAsString('''
import 'dart:io';
void main() {
  print(Platform.environment['SANDBOX_OUTPUT_JSON'] ?? 'NONE');
  print(Platform.environment['SANDBOX_OUTPUT'] ?? 'NONE');
}
''');
          final runner = SandboxRunner(null);
          final result = await runner.runSandboxed(
            [Platform.resolvedExecutable, script.path],
            outputFolder: '/tmp/a',
            outputFolders: ['/tmp/b'],
          );
          expect(result.exitCode, 0);
          final lines = result.stdout.asString.trim().split('\n');
          expect(json.decode(lines[0].trim()), ['/tmp/a', '/tmp/b']);
          expect(lines[1].trim(), '/tmp/a:/tmp/b');
        });
      },
    );

    test(
      'sets SANDBOX_OUTPUT_JSON and omits SANDBOX_OUTPUT when paths contain colons',
      () async {
        await withTempDir((dir) async {
          final script = File(p.join(dir, 'print_env.dart'));
          await script.writeAsString('''
import 'dart:io';
void main() {
  print(Platform.environment['SANDBOX_OUTPUT_JSON'] ?? 'NONE');
  print(Platform.environment['SANDBOX_OUTPUT'] ?? 'NONE');
}
''');
          final runner = SandboxRunner(null);
          final result = await runner.runSandboxed(
            [Platform.resolvedExecutable, script.path],
            outputFolder: '/tmp/gen/a:/home:',
            outputFolders: ['/tmp/valid', r'C:\Users\runner\out'],
          );
          expect(result.exitCode, 0);
          final lines = result.stdout.asString.trim().split('\n');
          expect(json.decode(lines[0].trim()), [
            '/tmp/gen/a:/home:',
            '/tmp/valid',
            r'C:\Users\runner\out',
          ]);
          expect(lines[1].trim(), 'NONE');
        });
      },
    );
  });
}
