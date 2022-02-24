// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../model.dart';
import '../package_context.dart';

import 'default_git_branch.dart';
import 'repository_url.dart';

/// Returns the repository information for the current package.
Future<Repository?> checkRepository(PackageContext context) async {
  final sourceUrl = context.pubspec.repository ?? context.pubspec.homepage;
  if (sourceUrl == null) {
    return null;
  }
  final url = RepositoryUrl.tryParse(sourceUrl);
  if (url == null) {
    return null;
  }
  final detectedGitBranch = context.options.checkRemoteRepository
      ? await tryDetectDefaultGitBranch(url.baseUrl)
      : null;
  final branch = detectedGitBranch ?? url.branch;
  return Repository(
    baseUrl: url.baseUrl,
    branch: branch,
    packagePath: url.path.isEmpty ? null : url.path,
  );
}
