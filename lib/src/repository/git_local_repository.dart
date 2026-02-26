// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../sandbox_runner.dart';
import '../tool/git_tool.dart';

final _acceptedBranchNameRegExp = RegExp(r'^[a-z0-9]+$');
final _acceptedPathSegmentsRegExp = RegExp(
  r'^[a-z0-9_\-\.]+$',
  caseSensitive: false,
);

/// The value to indicate we are fetching the branch without depth restriction.
const unlimitedFetchDepth = 0;

/// Interface for reading a remote git repository.
///
/// This objects uses a local temporary folder for interfacing with remote repository.
/// Hence, it is important to call [delete] or temporary files will be leaked.
class GitLocalRepository {
  /// The sandbox runner environment (if present).
  final SandboxRunner sandboxRunner;

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
    required this.sandboxRunner,
    required this.rootPath,
    required this.homePath,
    required this.localPath,
    required this.origin,
  });

  /// Creates a new local git repository by accessing the [origin] URL.
  ///
  /// Throws [GitToolException] if there was a failure to create the repository.
  static Future<GitLocalRepository> createLocalRepository(
    SandboxRunner sandboxRunner,
    String origin,
  ) async {
    final tempDir = await Directory.systemTemp.createTemp('git-repo');
    final homeDir = Directory(p.join(tempDir.path, 'home'));
    final localDir = Directory(p.join(tempDir.path, 'local'));
    await homeDir.create();
    await localDir.create();
    final repo = GitLocalRepository._(
      sandboxRunner: sandboxRunner,
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

  /// The git tool for running git commands.
  late final _gitTool = GitTool(
    sandboxRunner: sandboxRunner,
    homePath: homePath,
    workingDirectory: localPath,
  );

  Future<void> _init() async {
    await _gitTool.init();
    await _gitTool.addRemote('origin', origin);
  }

  /// Detects the default branch name (typically `master` or `main`)
  /// by querying the origin and matching `HEAD branch` in the output.
  ///
  /// Throws [GitToolException] if the git command fails, if the
  /// branch name is missing, or if the default branch name has
  /// unexpected pattern.
  Future<String> detectDefaultBranch() async {
    return await _gitTool.detectDefaultBranch('origin');
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
    return await _gitTool.showFile('origin/$branch', path);
  }

  /// List file names of [branch].
  ///
  /// Throws [GitToolException] if the git command fails.
  Future<List<String>> listFiles(String branch) async {
    _assertBranchFormat(branch);
    await _fetch(branch, 1);
    return await _gitTool.listFiles('origin/$branch');
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
    await _gitTool.fetch(
      'origin',
      branch,
      depth: depth == unlimitedFetchDepth ? null : depth,
    );
    _fetchedDepthsPerBranch[branch] = depth;
  }

  void _assertBranchFormat(String branch) {
    if (_acceptedBranchNameRegExp.matchAsPrefix(branch) == null) {
      throw GitToolException.argument('Branch name "$branch" is not accepted.');
    }
  }

  void _assertPathFormat(String path) {
    // Git always wants forward slashes. Even on windows.
    if (p.posix.normalize(path) != path) {
      throw GitToolException.argument('Path "$path" is not normalized.');
    }
    if (p
        .split(path)
        .any(
          (segment) =>
              _acceptedPathSegmentsRegExp.matchAsPrefix(segment) == null,
        )) {
      throw GitToolException.argument('Path "$path" is not accepted.');
    }
  }
}
