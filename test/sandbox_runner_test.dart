// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/sandbox_runner.dart';
import 'package:test/test.dart';

void main() {
  group('SandboxRunner', () {
    test('rejects outputFolder with colon when executable is set', () async {
      final runner = SandboxRunner('/path/to/sandbox');
      expect(
        () => runner.runSandboxed([
          'echo',
          'hello',
        ], outputFolder: '/tmp/gen/a:/home:'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must not contain ":"'),
          ),
        ),
      );
    });

    test('rejects outputFolders with colon when executable is set', () async {
      final runner = SandboxRunner('/path/to/sandbox');
      expect(
        () => runner.runSandboxed(
          ['echo', 'hello'],
          outputFolders: ['/tmp/valid', '/tmp/a:/b'],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must not contain ":"'),
          ),
        ),
      );
    });

    test('allows outputFolder with colon when executable is null', () async {
      final runner = SandboxRunner(null);
      final result = await runner.runSandboxed([
        Platform.resolvedExecutable,
        '--version',
      ], outputFolder: r'C:\Users\runner\AppData\Local\Temp\out');
      expect(result.exitCode, 0);
    });
  });
}
