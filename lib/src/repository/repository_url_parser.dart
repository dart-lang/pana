// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

import '../model.dart';

const _replaceSchemes = {
  'http': 'https',
};

const _replaceHosts = {
  'www.github.com': 'github.com',
  'www.gitlab.com': 'gitlab.com',
};

const _githubSegmentSeparators = ['tree', 'blob', 'raw'];

Repository? tryParseRepositoryUrl(String input) {
  try {
    return parseRepositoryUrl(input);
  } on FormatException {
    return null;
  }
}

Repository parseRepositoryUrl(String input) {
  var uri = Uri.parse(input);
  // trigger exception if there is an issue
  uri.pathSegments;
  uri.queryParameters;

  // apply known prefix replace patterns
  if (_replaceSchemes.containsKey(uri.scheme)) {
    uri = uri.replace(scheme: _replaceSchemes[uri.scheme]!);
  }
  if (_replaceHosts.containsKey(uri.host)) {
    uri = uri.replace(host: _replaceHosts[uri.host]!);
  }

  final provider = _detectProvider(uri);

  // Normalizing the URL path and rejecting URLs that may differ more than
  // a trailing slash.
  final normalizedUri = Uri.parse(p.normalize(uri.path));
  if (uri.path != normalizedUri.path && uri.path != '${normalizedUri.path}/') {
    throw FormatException(
        'URL path is not normalized: `${uri.path}` != `${normalizedUri.path}`');
  }
  // detect repo vs path segments
  final segments =
      normalizedUri.pathSegments.where((s) => s.isNotEmpty).toList();
  final repoSegmentIndex = _repoSegmentIndex(provider, segments);
  if (repoSegmentIndex < 0) {
    throw FormatException(
        'Could not find repository segment separator in `${normalizedUri.path}`.');
  }

  String? separator;
  String? branch;
  final extraSegments = segments.skip(repoSegmentIndex + 1).toList();
  if (RepositoryProvider.isGitHubCompatible(provider)) {
    if (extraSegments.isNotEmpty &&
        _githubSegmentSeparators.contains(extraSegments.first)) {
      separator = extraSegments.removeAt(0);
    }
    if (separator != null && extraSegments.isNotEmpty) {
      branch = extraSegments.removeAt(0);
    }
  }

  String? repository =
      Uri(pathSegments: segments.sublist(0, repoSegmentIndex + 1)).toString();
  if (repository.endsWith('.git')) {
    repository = repository.substring(0, repository.length - 4);
  }
  if (repository.isEmpty) {
    repository = null;
  }

  String? path = Uri(pathSegments: extraSegments).toString();
  if (path.isEmpty) {
    path = null;
  }

  return Repository(
    provider: provider,
    host: uri.host,
    repository: repository,
    branch: branch,
    path: path,
  );
}

RepositoryProvider _detectProvider(Uri uri) {
  if (uri.host == 'github.com') return RepositoryProvider.github;
  if (uri.host == 'gitlab.com') return RepositoryProvider.gitlab;
  return RepositoryProvider.unknown;
}

int _repoSegmentIndex(RepositoryProvider provider, List<String> segments) {
  // first segment with .git postfix
  final gitPostfixIndex = segments.indexWhere((s) => s.endsWith('.git'));
  if (gitPostfixIndex >= 0) return gitPostfixIndex;

  if (RepositoryProvider.isGitHubCompatible(provider)) {
    // detect segment separators, starting from the 3rd position
    for (final separator in _githubSegmentSeparators) {
      final index = segments.length <= 2 ? -1 : segments.indexOf(separator, 2);
      if (index >= 2) return index - 1;
    }

    // fallback
    if (segments.length == 2) return 1;
  }

  // couldn't find anything
  return -1;
}
