// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

import '../model.dart' show RepositoryProvider;

/// Describes the url + folder or file path of a repository URL.
class RepositoryUrl {
  /// One of the values from [RepositoryProvider].
  final RepositoryProvider? provider;

  /// The base URL up to the repository itself.
  final String baseUrl;

  /// The separator between the repository and the relative folder or file path.
  final String? separator;

  /// The branch to use.
  final String? branch;

  /// The relative folder or path of the repository.
  final String path;

  RepositoryUrl({
    this.provider = RepositoryProvider.unknown,
    required this.baseUrl,
    this.separator,
    this.branch,
    required this.path,
  });

  /// Parses [input] and return the parsed [RepositoryUrl] if successful,
  /// or returns null if it was unable to recognize the pattern.
  static RepositoryUrl? tryParse(String input) => _tryParseRepositoryUrl(input);

  /// Parses [input] and return the parsed [RepositoryUrl] if successful,
  /// or throws [FormatException] if it was unable to recognize the pattern.
  static RepositoryUrl parse(String input) {
    final v = tryParse(input);
    if (v == null) {
      throw FormatException('Invalid repository url: `$input`.');
    } else {
      return v;
    }
  }

  /// Resolves a relative path and returns a new instance of the [RepositoryUrl].
  RepositoryUrl resolve(
    String relativePath, {
    String? separator,
    String? branch,
  }) {
    final newPath = p.joinAll([
      if (path.isNotEmpty) path,
      if (relativePath.isNotEmpty) relativePath,
    ]);
    final normalizedNewPath = p.normalize(newPath);

    if (RepositoryProvider.isGitHubCompatible(provider)) {
      final extension = p.extension(normalizedNewPath).toLowerCase();
      final needsRaw = _imageExtensions.contains(extension);
      final newBaseUrl = baseUrl.endsWith('.git')
          ? baseUrl.substring(0, baseUrl.length - 4)
          : baseUrl;
      return RepositoryUrl(
        provider: provider,
        baseUrl: newBaseUrl,
        separator: separator ?? (needsRaw ? 'raw' : null) ?? 'blob',
        branch: branch ?? this.branch ?? 'master',
        path: normalizedNewPath,
      );
    } else {
      return RepositoryUrl(
        provider: provider,
        baseUrl: baseUrl,
        separator: separator,
        branch: branch,
        path: normalizedNewPath,
      );
    }
  }

  /// Creates a String representation of the URL.
  String toUrl() =>
      p.joinAll([baseUrl, separator, branch, path].whereType<String>());
}

const _replaceSchemes = {
  'http': 'https',
};

const _replaceHosts = {
  'www.github.com': 'github.com',
  'www.gitlab.com': 'gitlab.com',
};

const _githubSegmentSeparators = ['tree', 'blob', 'raw'];

final _imageExtensions = <String>{'.gif', '.jpg', '.jpeg', '.png'};

RepositoryUrl? _tryParseRepositoryUrl(String input) {
  var uri = Uri.tryParse(input);
  if (uri == null) return null;

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
  final normalizedUri = Uri.tryParse(p.normalize(uri.path));
  if (normalizedUri == null) {
    return null;
  }
  if (uri.path != normalizedUri.path && uri.path != '${normalizedUri.path}/') {
    return null;
  }
  // detect repo vs path segments
  final segments =
      normalizedUri.pathSegments.where((s) => s.isNotEmpty).toList();
  final repoSegmentIndex = _repoSegmentIndex(provider, segments);
  if (repoSegmentIndex < 0) return null;

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

  return RepositoryUrl(
    provider: provider,
    baseUrl: Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: segments.sublist(0, repoSegmentIndex + 1),
    ).toString(),
    separator: separator,
    branch: branch,
    path: extraSegments.join('/'),
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
