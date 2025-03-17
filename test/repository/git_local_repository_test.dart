// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/repository/git_local_repository.dart';
import 'package:pana/src/tool/git_tool.dart';
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

  group('local files', () {
    late GitLocalRepository repo;

    setUpAll(() async {
      repo = await GitLocalRepository.createLocalRepository(
          'https://github.com/dart-lang/pana.git');
    });

    tearDownAll(() async {
      await repo.delete();
    });

    void setupBranchFailures(Future<void> Function(String branch) fn) {
      test('no such branch', () async {
        await expectLater(
            () => fn('branchdoesnotexists'), throwsA(isA<GitToolException>()));
      });

      test('not expected branch format', () async {
        await expectLater(
            () => fn('not//accepted'), throwsA(isA<GitToolException>()));
      });
    }

    group('show string content', () {
      setupBranchFailures(
          (branch) async => await repo.showStringContent(branch, 'pubspec.yaml'));

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

    group('list files', () {
      setupBranchFailures((branch) async => await repo.listFiles(branch));

      test('list files in root', () async {
        final branch = await repo.detectDefaultBranch();
        final files = await repo.listFiles(branch);
        expect(
            files,
            containsAll([
              'lib/pana.dart',
              'pubspec.yaml',
            ]));
      });
    });
  });
}
