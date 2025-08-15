// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

import '../utils.dart';
import 'run_constrained.dart';

/// Runs `git` in an isolated environment using the [homePath] to access its
/// default configuration. This can be used to prevent the `git` process to
/// access the user's custom configuration files and settings, allowing a safe
/// and reproducible execution.
Future<PanaProcessResult> runGit(
  List<String> args, {
  required String homePath,
  required String workingDirectory,
  int? maxOutputBytes,
  GitToolException Function(PanaProcessResult pr)? createException,
}) async {
  final pr = await runConstrained(
    ['git', ...args],
    environment: {
      'LANG': 'C', // default English locale that is always present
      'LC_ALL': 'en_US',
      // prevent git from reading host configuration files
      'HOME': homePath,
      'GIT_CONFIG': p.join(homePath, '.gitconfig'),
      'GIT_CONFIG_GLOBAL': p.join(homePath, '.global-gitconfig'),
      'GIT_CONFIG_NOSYSTEM': '1',
      // prevent git from command prompts
      'GIT_TERMINAL_PROMPT': '0',
    },
    workingDirectory: workingDirectory,
    maxOutputBytes: maxOutputBytes,
  );
  if (pr.wasError) {
    final ex = createException == null
        ? GitToolException.failedToRun(args.join(' '), pr)
        : createException(pr);
    throw ex;
  }
  return pr;
}

/// Runs `git` with a temporary config directory, isolating it from any global
/// user settings.
Future<PanaProcessResult> runGitIsolated(
  List<String> args, {
  required String workingDirectory,
}) async {
  return await withTempDir((path) async {
    return runGit(args, homePath: path, workingDirectory: workingDirectory);
  });
}

class GitToolException implements Exception {
  final String message;
  final String? output;

  GitToolException(this.message, [this.output]);

  factory GitToolException.failedToRun(String command, PanaProcessResult pr) =>
      GitToolException('Failed to run `$command`.', pr.asJoinedOutput);

  GitToolException.argument(this.message) : output = null;

  @override
  String toString() => [message, output].whereType<String>().join('\n');
}
