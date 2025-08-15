// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:test/test.dart';

void main() {
  final timeout = const Duration(minutes: 5);
  test('running pana locally with relative path', () async {
    final pr = await runConstrained([
      'dart',
      'bin/pana.dart',
      '--no-warning',
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
  }, timeout: Timeout(timeout));
}
