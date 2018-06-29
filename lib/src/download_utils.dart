// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'logging.dart';
import 'utils.dart';

final imageExtensions = new Set.from(['.gif', '.jpg', '.jpeg', '.png']);

/// Returns a non-null Directory instance only if it is able to download and
/// extract the direct package dependency. On any failure it clears the temp
/// directory, otherwise it is the caller's responsibility to delete it.
Future<Directory> downloadPackage(String package, String version,
    {String pubHostedUrl}) async {
  final pubHostedUri = Uri.parse(pubHostedUrl ?? 'https://pub.dartlang.org');
  final temp = await Directory.systemTemp.createTemp('pana-');
  final dir = new Directory(await temp.resolveSymbolicLinks());
  try {
    final uri = pubHostedUri.replace(
        path: '/packages/$package/versions/$version.tar.gz');
    final bytes = await http.readBytes(uri);
    final archiveFileName = p.join(dir.path, '$package-$version.tar.gz');
    final archiveFile = new File(archiveFileName);
    await archiveFile.writeAsBytes(bytes);
    final pr = await runProc(
      'tar',
      ['-xzf', archiveFileName],
      workingDirectory: dir.path,
    );
    if (pr.exitCode == 0) {
      await archiveFile.delete();
      return dir;
    } else {
      log.warning(
          'Tar extraction failed with code=${pr.exitCode}: ${pr.stdout}');
    }
  } catch (e, st) {
    log.warning('Unable to download the archive of $package $version.', e, st);
  }
  return null;
}

/// Returns an URL that is likely the downloadable URL of the given path.
String getRepositoryUrl(String repository, String relativePath) {
  if (repository == null || repository.isEmpty) return null;
  for (var key in _repoReplacePrefixes.keys) {
    if (repository.startsWith(key)) {
      repository = repository.replaceFirst(key, _repoReplacePrefixes[key]);
    }
  }
  try {
    final uri = Uri.parse(repository);
    final segments = new List<String>.from(uri.pathSegments);
    while (segments.isNotEmpty && segments.last.isEmpty) {
      segments.removeLast();
    }

    if (repository.startsWith('https://github.com/') ||
        repository.startsWith('https://gitlab.com/')) {
      final extension = p.extension(relativePath).toLowerCase();
      final isRaw = imageExtensions.contains(extension);
      final typeSegment = isRaw ? 'raw' : 'blob';

      if (segments.length < 2) {
        return null;
      } else if (segments.length == 2) {
        return p.join(repository, typeSegment, 'master', relativePath);
      } else if (segments[2] == 'tree' || segments[2] == 'blob') {
        segments[2] = typeSegment;
        final newUrl = uri.replace(pathSegments: segments).toString();
        return p.join(newUrl, relativePath);
      } else {
        return null;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

const _repoReplacePrefixes = const {
  'http://github.com': 'https://github.com',
  'https://www.github.com': 'https://github.com',
  'https://www.gitlab.com': 'https://gitlab.com',
};

enum UrlStatus {
  invalid,
  internal,
  missing,
  exists,
}

class UrlChecker {
  final _internalHosts = new Set<Pattern>();
  final _resolveCache = <String, bool>{};
  final int _resolveCacheLimit;

  UrlChecker({
    int resolveCacheLimit: 1000,
  }) : _resolveCacheLimit = resolveCacheLimit {
    addInternalHosts([
      'dartlang.org',
      new RegExp(r'.*\.dartlang\.org'),
      'example.com',
      new RegExp(r'.*\.example.com'),
      'localhost',
    ]);
  }

  void addInternalHosts(Iterable<Pattern> hosts) {
    _internalHosts.addAll(hosts);
  }

  /// Check the hostname against known patterns.
  Future<bool> hasExternalHostname(Uri uri) async {
    if (uri == null) {
      return false;
    }
    return _internalHosts.every((p) => p.allMatches(uri.host).isEmpty);
  }

  /// Make sure that it is not an IP address.
  Future<bool> hasResolvableAddress(Uri uri) async {
    if (uri == null) {
      return false;
    }
    if (_resolveCache.containsKey(uri.host)) {
      return _resolveCache[uri.host];
    }
    try {
      final list = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 15));
      final result = list.every((a) => a.address != uri.host);

      while (_resolveCache.length > _resolveCacheLimit) {
        _resolveCache.remove(_resolveCache.keys.first);
      }
      _resolveCache[uri.host] = result;

      return result;
    } catch (_) {
      return false;
    }
  }

  /// Issues a HTTP HEAD request.
  Future<bool> urlExists(Uri uri) async {
    if (uri == null) {
      return false;
    }
    try {
      log.info('Requesting HEAD $uri ...');
      final rs = await http.head(uri).timeout(const Duration(seconds: 15));
      return rs.statusCode >= 200 && rs.statusCode < 300;
    } catch (e) {
      log.info('HEAD $uri failed', e);
    }
    return false;
  }

  Future<UrlStatus> checkStatus(String url) async {
    if (url == null) {
      return UrlStatus.invalid;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return UrlStatus.invalid;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return UrlStatus.invalid;
    }
    final isExternal = await hasExternalHostname(uri);
    if (!isExternal) {
      return UrlStatus.internal;
    }
    final isResolvable = await hasResolvableAddress(uri);
    if (!isResolvable) {
      return UrlStatus.invalid;
    }
    final exists = await urlExists(uri);
    return exists ? UrlStatus.exists : UrlStatus.missing;
  }
}
