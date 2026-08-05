// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/sandbox_runner.dart';
import 'package:test/test.dart';

void main() {
  group('SandboxRunner', () {
    test('rejects outputFolder with colon', () async {
      final runner = SandboxRunner(null);
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

    test('rejects outputFolders with colon', () async {
      final runner = SandboxRunner(null);
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
  });
}
