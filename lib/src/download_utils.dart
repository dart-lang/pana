// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:retry/retry.dart';
import 'package:safe_url_check/safe_url_check.dart';
import 'package:tar/tar.dart';

import 'logging.dart';

final _imageExtensions = <String>{'.gif', '.jpg', '.jpeg', '.png'};

/// Downloads [package] and unpacks it into [destination]
Future<void> downloadPackage(
  String package,
  String? version, {
  required String destination,
  String? pubHostedUrl,
}) async {
  // Find URI for the package tar-ball
  final pubHostedUri = Uri.parse(pubHostedUrl ?? 'https://pub.dartlang.org');
  if (version == null) {
    final versionsUri = pubHostedUri.replace(path: '/api/packages/$package');
    final versionsJson = json.decode(await http.read(versionsUri));
    version = versionsJson['latest']['version'] as String;
    log.fine('Latest version is: $version');
  }

  final packageUri = pubHostedUri.replace(
    path: '/packages/$package/versions/$version.tar.gz',
  );
  log.info('Downloading package $package $version from $packageUri');

  await retry(
    () async {
      final c = HttpClient();
      try {
        final req = await c.getUrl(packageUri);
        final res = await req.close();
        if (res.statusCode != 200) {
          throw AssertionError('Unable to access URL: "$packageUri".');
        }
        await _extractTarGz(res, destination);
      } finally {
        c.close(force: true);
      }
    },
    maxAttempts: 3,
  );
}

/// Returns an URL that is likely the downloadable URL of the given path.
String? getRepositoryUrl(String? repository, String relativePath) {
  if (repository == null || repository.isEmpty) return null;
  for (var key in _repoReplacePrefixes.keys) {
    if (repository!.startsWith(key)) {
      repository = repository.replaceFirst(key, _repoReplacePrefixes[key]!);
    }
  }
  try {
    final uri = Uri.parse(repository!);
    final segments = List<String>.from(uri.pathSegments);
    while (segments.isNotEmpty && segments.last.isEmpty) {
      segments.removeLast();
    }

    if (repository.startsWith('https://github.com/') ||
        repository.startsWith('https://gitlab.com/')) {
      if (segments.length >= 2 &&
          segments[1].endsWith('.git') &&
          segments[1].length > 4) {
        segments[1] = segments[1].substring(0, segments[1].length - 4);
      }

      final extension = p.extension(relativePath).toLowerCase();
      final isRaw = _imageExtensions.contains(extension);
      final typeSegment = isRaw ? 'raw' : 'blob';

      if (segments.length < 2) {
        return null;
      } else if (segments.length == 2) {
        final newUrl = uri.replace(pathSegments: segments).toString();
        return p.url.join(newUrl, typeSegment, 'master', relativePath);
      } else if (segments[2] == 'tree' || segments[2] == 'blob') {
        segments[2] = typeSegment;
        final newUrl = uri.replace(pathSegments: segments).toString();
        return p.url.join(newUrl, relativePath);
      } else {
        return null;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

const _repoReplacePrefixes = {
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

/// Checks if an URL is valid and accessible.
class UrlChecker {
  final _internalHosts = <Pattern>{};
  final _validUrlCache = <String>{};
  final int _maxCacheSize;

  UrlChecker({
    int? maxCacheSize,
  }) : _maxCacheSize = maxCacheSize ?? 10000 {
    addInternalHosts([
      'dart.dev',
      RegExp(r'.*\.dart\.dev'),
      'pub.dev',
      RegExp(r'.*\.pub\.dev'),
      'dartlang.org',
      RegExp(r'.*\.dartlang\.org'),
      'example.com',
      RegExp(r'.*\.example.com'),
      'localhost',
    ]);
  }

  /// Specify hosts internal to Dart. Non-internal packages
  /// should not reference internal hosts.
  void addInternalHosts(Iterable<Pattern> hosts) {
    _internalHosts.addAll(hosts);
  }

  /// Check the hostname against known patterns.
  Future<bool> hasExternalHostname(Uri uri) async {
    return _internalHosts.every((p) => p.allMatches(uri.host).isEmpty);
  }

  /// Check the status of the URL, using validity checks, cache and
  /// safe URL checks with limited number of redirects.
  Future<UrlStatus> checkStatus(String url,
      {bool isInternalPackage = false}) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return UrlStatus.invalid;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return UrlStatus.invalid;
    }
    final isExternal = await hasExternalHostname(uri);
    if (!isExternal && !isInternalPackage) {
      return UrlStatus.internal;
    }

    // check in cache
    if (await existsInCache(uri)) {
      return UrlStatus.exists;
    }

    final exists = await safeUrlCheck(uri);
    if (exists) {
      await markExistsInCache(uri);
      return UrlStatus.exists;
    } else {
      return UrlStatus.missing;
    }
  }

  /// Checks if the [uri] exists in cache. The cache contains only
  /// the valid URLs, failures (which may be short-lived, transient)
  /// are not stored, rather retried.
  ///
  /// Returns true if [uri] has been valid in the cache, false otherwise.
  Future<bool> existsInCache(Uri uri) async {
    return _validUrlCache.contains(uri.toString());
  }

  /// Marks the [uri] as valid in the cache.
  Future<void> markExistsInCache(Uri uri) async {
    while (_validUrlCache.length > _maxCacheSize) {
      _validUrlCache.remove(_validUrlCache.first);
    }
    _validUrlCache.add(uri.toString());
  }
}

/// Extracts a `.tar.gz` file from [tarball] to [destination].
Future _extractTarGz(Stream<List<int>> tarball, String destination) async {
  log.fine('Extracting .tar.gz stream to $destination.');
  final reader = TarReader(tarball.transform(gzip.decoder));
  while (await reader.moveNext()) {
    final entry = reader.current;
    final path = p.join(destination, entry.name);
    if (!p.isWithin(destination, path)) {
      throw ArgumentError('"${entry.name}" is outside of the archive.');
    }
    final dir = File(path).parent;
    await dir.create(recursive: true);
    if (entry.header.linkName != null) {
      final target = p.normalize(p.join(dir.path, entry.header.linkName));
      if (p.isWithin(destination, target)) {
        final link = Link(path);
        if (!link.existsSync()) {
          await link.create(target);
        }
      } else {
        log.info('Link from "$path" points outside of the archive: "$target".');
        // Note to self: do not create links going outside the package, this is not safe!
      }
    } else {
      await entry.contents.pipe(File(path).openWrite());
    }
  }
}
