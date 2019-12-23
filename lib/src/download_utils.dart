// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:safe_url_check/safe_url_check.dart';

import 'logging.dart';
import 'utils.dart';

final imageExtensions = <String>{'.gif', '.jpg', '.jpeg', '.png'};

/// Returns a non-null Directory instance only if it is able to download and
/// extract the direct package dependency. On any failure it clears the temp
/// directory, otherwise it is the caller's responsibility to delete it.
Future<Directory> downloadPackage(
  String package,
  String version, {
  String pubHostedUrl,
}) async {
  // Find URI for the package tar-ball
  final pubHostedUri = Uri.parse(pubHostedUrl ?? 'https://pub.dartlang.org');
  final packageUri = pubHostedUri.replace(
    path: '/packages/$package/versions/$version.tar.gz',
  );

  // Create a temporary directory for the tar-ball
  final tmpTarDir = await Directory.systemTemp.createTemp('pana-');
  var tmpPkgDir = await Directory.systemTemp.createTemp('pana-');
  tmpPkgDir = Directory(await tmpPkgDir.resolveSymbolicLinks());
  try {
    // Download package
    final tarballFile = p.join(tmpTarDir.uri.toFilePath(), 'pkg.tar.gz');
    // TODO: Wrap this in retry-loop using package:retry
    await File(tarballFile).writeAsBytes(await http.readBytes(packageUri));

    // Extract downloaded package
    final tar = await runProc('/bin/tar', [
      '-xzf',
      tarballFile,
      '-C',
      tmpPkgDir.path,
    ]);
    if (tar.exitCode != 0) {
      log.warning(
          'Tar extraction failed with exitcode=${tar.exitCode}: ${tar.stdout}');
      return null;
    }

    // Delete all symlinks in the extracted folder
    await Future.wait(
      await tmpPkgDir
          .list(recursive: true, followLinks: false)
          .where((e) => e is Link)
          .map((e) => e.delete())
          .toList(),
    );

    // Removed all executable permissions from extracted files
    final chmod = await runProc('/bin/chmod', [
      '-R',
      '-x+X',
      tmpPkgDir.path,
    ]);
    if (chmod.exitCode != 0) {
      log.severe('chmod of extract data failed');
      return null;
    }

    // Return the tmpPkgDir
    final retval = tmpPkgDir;
    tmpPkgDir = null; // ensure this is null, so it's not deleted in final
    return retval;
  } catch (e, st) {
    log.warning('Unable to download the archive of $package $version.', e, st);
  } finally {
    await Future.wait([
      tmpTarDir.delete(recursive: true),
      if (tmpPkgDir != null) tmpPkgDir.delete(recursive: true),
    ]);
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
    final segments = List<String>.from(uri.pathSegments);
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

class UrlChecker {
  final _internalHosts = <Pattern>{};

  UrlChecker() {
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

  Future<UrlStatus> checkStatus(String url,
      {bool isInternalPackage = false}) async {
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
    if (!isExternal && !isInternalPackage) {
      return UrlStatus.internal;
    }
    final exists = await safeUrlCheck(uri);
    return exists ? UrlStatus.exists : UrlStatus.missing;
  }
}
