// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/pana.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final timeout = const Duration(minutes: 5);
  test('running pana locally with compiled executable', () async {
    await withTempDir((dir) async {
      // build pana CLI bundle (runs hook/build.dart with linkingEnabled == true)
      final compilePr = await Process.run(Platform.resolvedExecutable, [
        'build',
        'cli',
        '--target',
        p.join('bin', 'pana.dart'),
        '--output',
        dir,
      ]);
      expect(
        compilePr.exitCode,
        0,
        reason:
            'dart build cli failed\n${compilePr.stdout}\n${compilePr.stderr}',
      );
      final compiledBinaryPath = p.join(
        dir,
        'bundle',
        'bin',
        Platform.isWindows ? 'pana.exe' : 'pana',
      );

      // run pana without --dart-sdk or --license-data to verify AOT defaults
      final pr = await runConstrained([
        compiledBinaryPath,
        '--no-warning',
        '.',
      ], timeout: timeout);
      expect(pr.exitCode, 0, reason: pr.asJoinedOutput);

      final output = pr.stdout.asString.replaceAll('\r\n', '\n');
      final snippets = [
        '## ✓ Follow Dart file conventions (30 / 30)',
        '## ✓ Platform support (20 / 20)\n',
        // TODO: consider dropping this, as we don't always resolve to the latest dependencies
        // '[*] 10/10 points: All of the package dependencies are supported in the latest version',
        '### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs',
      ];
      for (final snippet in snippets) {
        expect(output, contains(snippet));
      }
    });
  }, timeout: Timeout(timeout));
}
