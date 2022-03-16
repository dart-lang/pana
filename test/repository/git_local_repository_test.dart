// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/repository/git_local_repository.dart';
import 'package:test/test.dart';

void main() {
  group('git branch', () {
    Future<String?> getDefaultBranch(String url) async {
      GitLocalRepository? repo;
      try {
        repo = await GitLocalRepository.createLocalRepository(url);
        return await repo.detectDefaultBranch();
      } on GitToolException catch (_) {
        return null;
      } finally {
        await repo?.delete();
      }
    }

    test('master', () async {
      expect(await getDefaultBranch('https://github.com/dart-lang/pana.git'),
          'master');
    });

    test('main', () async {
      expect(
          await getDefaultBranch('https://github.com/dart-lang/lints'), 'main');
    });

    test('bad url', () async {
      expect(await getDefaultBranch('https://example.com/org/repo'), null);
    });
  });

  group('checkout files', () {
    late GitLocalRepository repo;

    setUpAll(() async {
      repo = await GitLocalRepository.createLocalRepository(
          'https://github.com/dart-lang/pana.git');
    });

    tearDownAll(() async {
      await repo.delete();
    });

    test('no such branch', () async {
      await expectLater(
        () => repo.showStringContent('branchdoesnotexists', 'pubspec.yaml'),
        throwsA(isA<GitToolException>()),
      );
    });

    test('not expected branch format', () async {
      await expectLater(
        () => repo.showStringContent('branch-is-not-accepted', 'pubspec.yaml'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('bad file', () async {
      final branch = await repo.detectDefaultBranch();
      await expectLater(
        () => repo.showStringContent(branch, 'no-such-pubspec.yaml'),
        throwsA(isA<GitToolException>()),
      );
    });

    test('checkout files from default branch', () async {
      final branch = await repo.detectDefaultBranch();
      final content = await repo.showStringContent(branch, 'pubspec.yaml');
      expect(content, contains('name: pana'));
    });
  });
}
