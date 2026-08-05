// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/package_context.dart';
import 'package:pana/src/repository/check_repository.dart';
import 'package:test/test.dart';

void main() {
  group('checkRepository', () {
    late ToolEnvironment toolEnv;

    setUpAll(() async {
      toolEnv = await ToolEnvironment.create();
    });

    test('missing URL', () async {
      final result = await checkRepository(
        sharedContext: SharedAnalysisContext(toolEnvironment: toolEnv),
        packageName: 'pana',
        sourceUrl: null,
      );
      expect(result.status, RepositoryStatus.missing);
      expect(result.verificationFailure, 'Repository URL is missing.');
    });

    test('empty URL', () async {
      final result = await checkRepository(
        sharedContext: SharedAnalysisContext(toolEnvironment: toolEnv),
        packageName: 'pana',
        sourceUrl: '   ',
      );
      expect(result.status, RepositoryStatus.missing);
      expect(result.verificationFailure, 'Repository URL is missing.');
    });

    test('invalid URL', () async {
      final result = await checkRepository(
        sharedContext: SharedAnalysisContext(toolEnvironment: toolEnv),
        packageName: 'pana',
        sourceUrl: 'https://example.com/not/github/repo',
      );
      expect(result.status, RepositoryStatus.invalid);
      expect(
        result.verificationFailure,
        contains('Could not recognize URL segments'),
      );
    });

    test(
      'private/loopback URL is rejected without git access (SSRF)',
      () async {
        final result = await checkRepository(
          sharedContext: SharedAnalysisContext(toolEnvironment: toolEnv),
          packageName: 'pana',
          sourceUrl: 'https://127.0.0.1/dart-lang/pana.git',
        );
        expect(result.status, RepositoryStatus.missing);
        expect(
          result.verificationFailure,
          contains('does not exist or is not reachable'),
        );
      },
    );

    test('non-existent repository URL', () async {
      final result = await checkRepository(
        sharedContext: SharedAnalysisContext(toolEnvironment: toolEnv),
        packageName: 'pana',
        sourceUrl:
            'https://github.com/dart-lang/non-existing-repository-1234567',
      );
      expect(result.status, RepositoryStatus.missing);
      expect(
        result.verificationFailure,
        contains('does not exist or is not reachable'),
      );
    });

    test('verified repository', () async {
      final result = await checkRepository(
        sharedContext: SharedAnalysisContext(toolEnvironment: toolEnv),
        packageName: 'pana',
        sourceUrl: 'https://github.com/dart-lang/pana',
      );
      expect(result.status, RepositoryStatus.verified);
      expect(result.verificationFailure, isNull);
      expect(result.repository?.repository, 'dart-lang/pana');
    });

    test('package name mismatch in repository', () async {
      final result = await checkRepository(
        sharedContext: SharedAnalysisContext(toolEnvironment: toolEnv),
        packageName: 'non_existing_pkg_name',
        sourceUrl: 'https://github.com/dart-lang/pana',
      );
      expect(result.status, RepositoryStatus.failed);
      expect(
        result.verificationFailure,
        'Repository has no matching `pubspec.yaml` with `name: non_existing_pkg_name`.',
      );
    });
  });
}
