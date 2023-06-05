// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:retry/retry.dart';

import '../utils.dart' show runProc, PanaProcessResult;

final _acceptedBranchNameRegExp = RegExp(r'^[a-z0-9]+$');
final _acceptedPathSegmentsRegExp =
    RegExp(r'^[a-z0-9_\-\.\{\}\(\)]+$', caseSensitive: false);

/// The value to indicate we are fetching the branch without depth restriction.
const unlimitedFetchDepth = 0;

/// Interface for reading a remote git repository.
///
/// This objects uses a local temporary folder for interfacing with remote repository.
/// Hence, it is important to call [delete] or temporary files will be leaked.
class GitLocalRepository {
  /// The temporary directory which contains all the other directories.
  final String rootPath;

  /// The local filesystem path to act as $HOME.
  final String homePath;

  /// The local filesystem path to store the git repository.
  final String localPath;

  /// The remote origin URL of the git repository.
  final String origin;

  /// Stores the currently fetched depth level for each branch.
  /// When the depth was unlimited (== `0`), this stores `0`.
  final _fetchedDepthsPerBranch = <String, int>{};

  GitLocalRepository._({
    required this.rootPath,
    required this.homePath,
    required this.localPath,
    required this.origin,
  });

  /// Creates a new local git repository by accessing the [origin] URL.
  ///
  /// Throws [GitToolException] if there was a failure to create the repository.
  static Future<GitLocalRepository> createLocalRepository(String origin) async {
    final tempDir = await Directory.systemTemp.createTemp('git-repo');
    final homeDir = Directory(p.join(tempDir.path, 'home'));
    final localDir = Directory(p.join(tempDir.path, 'local'));
    await homeDir.create();
    await localDir.create();
    final repo = GitLocalRepository._(
      rootPath: tempDir.path,
      homePath: homeDir.path,
      localPath: localDir.path,
      origin: origin,
    );
    try {
      await repo._init();
      return repo;
    } on Exception catch (_) {
      await repo.delete();
      rethrow;
    }
  }

  Future<PanaProcessResult> _runGit(
    List<String> args, {
    int? maxOutputBytes,
    GitToolException Function(PanaProcessResult pr)? createException,
  }) async {
    final pr = await runProc(
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
      workingDirectory: localPath,
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

  Future<PanaProcessResult> _runGitWithRetry(
    List<String> args, {
    int maxAttempts = 3,
    GitToolException Function(PanaProcessResult pr)? createException,
    int? maxOutputBytes,
  }) async {
    return await retry(
      () => _runGit(
        args,
        maxOutputBytes: maxOutputBytes,
        createException: createException,
      ),
      maxAttempts: maxAttempts,
      retryIf: (e) => e is GitToolException,
    );
  }

  Future<void> _init() async {
    await _runGit(['init']);
    await _runGit(['remote', 'add', 'origin', origin]);
  }

  /// Detects the default branch name (typically `master` or `main`)
  /// by querying the origin and matching `HEAD branch` in the output.
  ///
  /// Throws [GitToolException] if the git command fails, if the
  /// branch name is missing, or if the default branch name has
  /// unexpected pattern.
  Future<String> detectDefaultBranch() async {
    final pr = await _runGitWithRetry(['remote', 'show', 'origin']);
    final output = pr.stdout.asString;
    final lines = output.split('\n');
    for (final line in lines) {
      final parts = line.trim().split(':');
      if (parts.length == 2 && parts[0].trim() == 'HEAD branch') {
        final branch = parts[1].trim();
        if (_acceptedBranchNameRegExp.matchAsPrefix(branch) != null) {
          return branch;
        } else {
          throw GitToolException('Could not accept branch name: `$branch`.');
        }
      }
    }
    throw GitToolException('Could not find HEAD branch.', output);
  }

  /// Return the String content of the file in [branch] and [path].
  ///
  /// Throws [GitToolException] if the git command fails.
  Future<String> showStringContent(
    String branch,
    String path, {
    int? maxOutputBytes,
  }) async {
    _assertBranchFormat(branch);
    _assertPathFormat(path);
    await _fetch(branch, 1);
    final pr = await _runGitWithRetry(
      [
        'show',
        'origin/$branch:$path',
      ],
      createException: (_) => GitToolException('Could not read `$path`.'),
    );
    return pr.stdout.asString;
  }

  /// List file names of [branch].
  ///
  /// Throws [GitToolException] if the git command fails.
  Future<List<String>> listFiles(String branch) async {
    _assertBranchFormat(branch);
    await _fetch(branch, 1);
    final pr = await _runGitWithRetry(
      [
        'ls-tree',
        '-r',
        '--name-only',
        '--full-tree',
        'origin/$branch',
      ],
      createException: (pr) =>
          GitToolException('Could not list `$branch`.', pr.asTrimmedOutput),
    );
    return pr.stdout
        .toString()
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Deletes the local directory.
  Future<void> delete() async {
    await Directory(rootPath).delete(recursive: true);
  }

  Future<void> _fetch(String branch, int depth) async {
    final currentDepth = _fetchedDepthsPerBranch[branch];
    if (currentDepth != null &&
        (currentDepth >= depth || currentDepth == unlimitedFetchDepth)) {
      return;
    }
    _assertBranchFormat(branch);
    await _runGitWithRetry([
      'fetch',
      if (depth != unlimitedFetchDepth) ...['--depth', '$depth'],
      '--no-recurse-submodules',
      'origin',
      branch,
    ]);
    _fetchedDepthsPerBranch[branch] = depth;
  }

  void _assertBranchFormat(String branch) {
    if (_acceptedBranchNameRegExp.matchAsPrefix(branch) == null) {
      throw ArgumentError('Branch name "$branch" is not accepted.');
    }
  }

  void _assertPathFormat(String path) {
    if (p.normalize(path) != path) {
      throw ArgumentError('Path "$path" is not normalized.');
    }
    if (p.split(path).any((segment) =>
        _acceptedPathSegmentsRegExp.matchAsPrefix(segment) == null)) {
      throw ArgumentError('Path "$path" is not accepted.');
    }
  }
}

class GitToolException implements Exception {
  final String message;
  final String? output;

  GitToolException(this.message, [this.output]);

  factory GitToolException.failedToRun(String command, PanaProcessResult pr) =>
      GitToolException('Failed to run `$command`.', pr.asJoinedOutput);

  @override
  String toString() => [message, output].whereType<String>().join('\n');
}
