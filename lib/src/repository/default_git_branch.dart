// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:retry/retry.dart';

import '../logging.dart';
import '../utils.dart' show runProc, withTempDir;

final _acceptedBranchNameRegExp = RegExp(r'^[a-z0-9]+$');

/// Detects the name of the default git branch on the given [baseUrl],
/// using the metadata returned by `git remote show`.
///
/// Returns `null` when no branch name can be detected, or the implied
/// branch name does not conform of the allowed patterns.
Future<String?> tryDetectDefaultGitBranch(String baseUrl) async {
  return await withTempDir((dir) async {
    final initPr = await runProc(
      ['git', 'init', dir],
      workingDirectory: dir,
    );
    if (initPr.exitCode != 0) {
      log.warning('Failed to run `git init`.\n${initPr.asJoinedOutput}');
      return null;
    }
    final remoteAddPr = await runProc(
      ['git', 'remote', 'add', 'origin', baseUrl],
      workingDirectory: dir,
    );
    if (remoteAddPr.exitCode != 0) {
      log.warning(
          'Failed to run `git remote add`.\n${remoteAddPr.asJoinedOutput}');
      return null;
    }
    ProcessResult? remoteShowPr;
    try {
      remoteShowPr = await retry(
        () async {
          final pr = await runProc(
            ['git', 'remote', 'show', 'origin'],
            workingDirectory: dir,
          );
          if (pr.exitCode != 0) {
            log.warning(
                'Failed to run `git remote show`.\n${pr.asJoinedOutput}');
            throw _RetryGitException();
          }
          return pr;
        },
        retryIf: (e) => e is _RetryGitException,
        maxAttempts: 3,
      );
    } on _RetryGitException catch (_) {
      return null;
    }
    final lines = remoteShowPr!.stdout.toString().split('\n');
    for (final line in lines) {
      final parts = line.trim().split(':');
      if (parts.length == 2 && parts[0].trim() == 'HEAD branch') {
        final branch = parts[1].trim();
        if (_acceptedBranchNameRegExp.matchAsPrefix(branch) != null) {
          return branch;
        } else {
          return null;
        }
      }
    }
    return null;
  });
}

class _RetryGitException implements Exception {}
