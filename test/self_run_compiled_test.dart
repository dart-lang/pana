// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
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
      // detect SDK directory
      final dartPathPr = await Process.run('which', ['dart']);
      var sdkPath = Directory(
        p.dirname(p.dirname(dartPathPr.stdout.toString())),
      ).resolveSymbolicLinksSync();
      // if we using Flutter SDK, we need to use the internal Dart SDK's directory
      if (await File(p.join(sdkPath, 'bin', 'flutter')).exists()) {
        sdkPath = p.join(sdkPath, 'bin', 'cached', 'dart-sdk');
      }

      // compile pana binary
      final compiledBinaryPath = p.join(dir, 'pana');
      final compilePr = await Process.run('dart', [
        'compile',
        'exe',
        '-o',
        compiledBinaryPath,
        p.join('bin', 'pana.dart'),
      ]);
      expect(
        compilePr.exitCode,
        0,
        reason: 'dart compile failed\n${compilePr.stdout}\n${compilePr.stderr}',
      );

      // run pana
      final pr = await runConstrained([
        compiledBinaryPath,
        '--no-warning',
        '--dart-sdk',
        sdkPath,
        '--license-data',
        p.join('lib', 'src', 'third_party', 'spdx', 'licenses'),
        '.',
      ], timeout: timeout);
      expect(pr.exitCode, 0, reason: pr.asJoinedOutput);

      final output = pr.stdout.asString;
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
