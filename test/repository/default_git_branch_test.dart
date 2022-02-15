// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/repository/default_git_branch.dart';
import 'package:test/test.dart';

void main() {
  Future<void> expectGitBranch(String url, branch) async {
    final r = await tryDetectDefaultGitBranch(url);
    expect(r, branch);
  }

  test('master', () async {
    await expectGitBranch('https://github.com/dart-lang/pana.git', 'master');
  });

  test('main', () async {
    await expectGitBranch('https://github.com/dart-lang/lints', 'main');
  });

  test('bad url', () async {
    await expectGitBranch('https://example.com/org/repo', null);
  });
}
