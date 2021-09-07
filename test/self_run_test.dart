// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:pana/pana.dart';

void main() {
  test('running pana locally with relative path', () async {
    final pr = await runProc(['dart', 'bin/pana.dart', '.']);
    expect(pr.exitCode, 0);

    final output = pr.stdout.toString();
    final snippets = [
      'The package description is too short.',
      'Support multiple platforms (10 / 20)',
      '[*] 10/10 points: All of the package dependencies are supported in the latest version',
      'Support sound null safety (20 / 20)',
    ];
    for (final snippet in snippets) {
      expect(output, contains(snippet));
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
