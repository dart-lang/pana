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
    test('JSON-encodes output folders when executable is set', () async {
      await withTempDir((dir) async {
        final script = File(p.join(dir, 'print_env.dart'));
        await script.writeAsString('''
import 'dart:io';
void main() {
  print(Platform.environment['SANDBOX_OUTPUT'] ?? 'NONE');
}
''');
        final runner = SandboxRunner(Platform.resolvedExecutable);
        final result = await runner.runSandboxed(
          [script.path],
          outputFolder: '/tmp/gen/a:/home:',
          outputFolders: ['/tmp/valid', r'C:\Users\runner\out'],
        );
        expect(result.exitCode, 0);
        expect(json.decode(result.stdout.asString.trim()), [
          '/tmp/gen/a:/home:',
          '/tmp/valid',
          r'C:\Users\runner\out',
        ]);
      });
    });

    test('does not set SANDBOX_OUTPUT when executable is null', () async {
      await withTempDir((dir) async {
        final script = File(p.join(dir, 'print_env.dart'));
        await script.writeAsString('''
import 'dart:io';
void main() {
  print(Platform.environment['SANDBOX_OUTPUT'] ?? 'NONE');
}
''');
        final runner = SandboxRunner(null);
        final result = await runner.runSandboxed([
          Platform.resolvedExecutable,
          script.path,
        ], outputFolder: r'C:\Users\runner\AppData\Local\Temp\out');
        expect(result.exitCode, 0);
        expect(result.stdout.asString.trim(), 'NONE');
      });
    });
  });
}
