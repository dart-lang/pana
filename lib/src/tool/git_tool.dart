// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:retry/retry.dart';

import '../sandbox_runner.dart';
import 'run_constrained.dart';

/// Runs `git` in an isolated environment using the [homePath] to access its
/// default configuration. This can be used to prevent the `git` process to
/// access the user's custom configuration files and settings, allowing a safe
/// and reproducible execution.
Future<PanaProcessResult> _runGit(
  SandboxRunner sandboxRunner,
  List<String> args, {
  required String homePath,
  required String workingDirectory,
  int? maxOutputBytes,
  GitToolException Function(PanaProcessResult pr)? createException,
}) async {
  final pr = await sandboxRunner.runSandboxed(
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
    needsNetwork: true,
    outputFolder: homePath, // allow home path updates
    writableCurrentDir: true,
  );
  if (pr.wasError) {
    final ex = createException == null
        ? GitToolException.failedToRun(args.join(' '), pr)
        : createException(pr);
    throw ex;
  }
  return pr;
}

/// Encapsulates high-level git operations.
class GitTool {
  final SandboxRunner _sandboxRunner;
  final String _homePath;
  final String _workingDirectory;

  GitTool({
    required SandboxRunner sandboxRunner,
    required String homePath,
    required String workingDirectory,
  }) : _sandboxRunner = sandboxRunner,
       _homePath = homePath,
       _workingDirectory = workingDirectory;

  /// Runs a git command with the configured paths.
  Future<PanaProcessResult> _run(
    List<String> args, {
    int? maxOutputBytes,
    GitToolException Function(PanaProcessResult pr)? createException,
  }) async {
    return await _runGit(
      _sandboxRunner,
      args,
      homePath: _homePath,
      workingDirectory: _workingDirectory,
      maxOutputBytes: maxOutputBytes,
      createException: createException,
    );
  }

  /// Runs a git command with retry logic.
  Future<PanaProcessResult> _runWithRetry(
    List<String> args, {
    int maxAttempts = 3,
    int? maxOutputBytes,
    GitToolException Function(PanaProcessResult pr)? createException,
  }) async {
    return await retry(
      () => _run(
        args,
        maxOutputBytes: maxOutputBytes,
        createException: createException,
      ),
      maxAttempts: maxAttempts,
      retryIf: (e) => e is GitToolException,
    );
  }

  /// Initialize a new git repository.
  Future<void> init() async {
    await _run(['init']);
  }

  /// Add a remote to the repository.
  Future<void> addRemote(String name, String url) async {
    await _run(['remote', 'add', name, url]);
  }

  /// Returns the root directory of the repository.
  ///
  /// Returns `null` if not inside a git repository.
  Future<String?> detectRootDir() async {
    try {
      final pr = await _run(['rev-parse', '--show-toplevel']);
      return pr.stdout.asString.trim();
    } on GitToolException catch (_) {
      return null;
    }
  }

  /// Detect the default branch name of a remote (typically 'master' or 'main').
  ///
  /// Throws [GitToolException] if the branch cannot be detected or has an unexpected format.
  Future<String> detectDefaultBranch(String remote) async {
    final pr = await _runWithRetry(['remote', 'show', remote]);
    final output = pr.stdout.asString;
    final lines = output.split('\n');

    final branchNameRegExp = RegExp(r'^[a-z0-9]+$');

    for (final line in lines) {
      final parts = line.trim().split(':');
      if (parts.length == 2 && parts[0].trim() == 'HEAD branch') {
        final branch = parts[1].trim();
        if (branchNameRegExp.matchAsPrefix(branch) != null) {
          return branch;
        } else {
          throw GitToolException('Could not accept branch name: `$branch`.');
        }
      }
    }
    throw GitToolException('Could not find HEAD branch.', output);
  }

  /// Fetch a branch from a remote.
  Future<void> fetch(String remote, String branch, {int? depth}) async {
    await _runWithRetry([
      'fetch',
      if (depth != null) ...['--depth', '$depth'],
      '--no-recurse-submodules',
      remote,
      branch,
    ]);
  }

  /// Read the content of a file at a specific ref (e.g., 'origin/main:path/to/file').
  Future<String> showFile(String ref, String path) async {
    final pr = await _runWithRetry([
      'show',
      '$ref:$path',
    ], createException: (_) => GitToolException('Could not read `$path`.'));
    return pr.stdout.asString;
  }

  /// List all files at a specific ref (e.g., 'origin/main').
  Future<List<String>> listFiles(String ref) async {
    final pr = await _runWithRetry(
      ['ls-tree', '-r', '-z', '--name-only', '--full-tree', ref],
      createException: (pr) =>
          GitToolException('Could not list `$ref`.', pr.asTrimmedOutput),
    );
    return pr.stdout.asBytes
        .splitBefore((b) => b == 0)
        .where((chunk) => chunk.isNotEmpty)
        .map((chunk) => chunk.first == 0 ? utf8.decode(chunk.sublist(1)) : '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
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
