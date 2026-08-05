// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/sandbox_runner.dart';
import 'package:pana/src/tool/git_tool.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GitTool', () {
    late Directory tempDir;
    late String homePath;
    late GitTool gitTool;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('git-tool-test');
      homePath = p.join(tempDir.path, 'home');
      final repoPath = p.join(tempDir.path, 'repo');
      Directory(homePath).createSync();
      Directory(repoPath).createSync();

      gitTool = GitTool(
        sandboxRunner: SandboxRunner(null),
        homePath: homePath,
        workingDirectory: repoPath,
      );

      File(p.join(repoPath, 'a-first.txt')).writeAsStringSync('a');
      File(p.join(repoPath, 'b-second.txt')).writeAsStringSync('b');
      Directory(p.join(repoPath, 'lib')).createSync();
      File(p.join(repoPath, 'lib', 'c-third.dart')).writeAsStringSync('c');

      await gitTool.init();
      await gitTool.configure();
      await gitTool.run(['add', '.']);
      await gitTool.run(['commit', '-m', 'initial']);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'configure writes the committer email to the provided config',
      () async {
        final config = File(p.join(homePath, '.global-gitconfig'));
        expect(config.readAsStringSync(), contains('test@example.com'));
      },
    );

    test('lists all files, including the first tree entry', () async {
      final files = await gitTool.listFiles('HEAD');
      expect(
        files,
        unorderedEquals(['a-first.txt', 'b-second.txt', 'lib/c-third.dart']),
      );
    });

    test('showFile returns file contents', () async {
      final content = await gitTool.showFile('HEAD', 'a-first.txt');
      expect(content, 'a');
    });

    test('showFile respects maxOutputBytes', () async {
      File(
        p.join(tempDir.path, 'repo', 'large.txt'),
      ).writeAsStringSync('0123456789' * 100);
      await gitTool.run(['add', 'large.txt']);
      await gitTool.run(['commit', '-m', 'add large file']);

      await expectLater(
        () => gitTool.showFile('HEAD', 'large.txt', maxOutputBytes: 50),
        throwsA(isA<GitToolException>()),
      );

      final content = await gitTool.showFile(
        'HEAD',
        'large.txt',
        maxOutputBytes: 2000,
      );
      expect(content, '0123456789' * 100);
    });
  });
}
