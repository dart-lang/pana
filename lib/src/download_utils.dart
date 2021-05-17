// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:retry/retry.dart';
import 'package:safe_url_check/safe_url_check.dart';
import 'package:tar/tar.dart';

import 'logging.dart';
import 'utils.dart';

final imageExtensions = <String>{'.gif', '.jpg', '.jpeg', '.png'};

Future<String> getVersionListing(String package, {Uri pubHostedUrl}) async {
  final url = (pubHostedUrl ?? Uri.parse('https://pub.dartlang.org'))
      .resolve('/api/packages/$package');
  log.fine('Downloading: $url');

  return await retry(() => http.read(url),
      retryIf: (e) => e is SocketException || e is TimeoutException);
}

/// Downloads [package] and unpacks it into [destination]
Future<void> downloadPackage(
  String package,
  String version, {
  @required String destination,
  String pubHostedUrl,
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
  log.info(
      'Downloading package $package ${version ?? 'latest'} from $packageUri');

  await extractTarGz(await http.readBytes(packageUri), destination);

  // Delete all symlinks in the extracted folder
  await Future.wait(
    await Directory(destination)
        .list(recursive: true, followLinks: false)
        .where((e) => e is Link)
        .map((e) => e.delete())
        .toList(),
  );

  if (!Platform.isWindows) {
    // Remove all executable permissions from extracted files
    final chmod = await runProc([
      '/bin/chmod',
      '-R',
      '-x+X',
      destination,
    ]);
    if (chmod.exitCode != 0) {
      throw const FileSystemException('chmod of extract data failed');
    }
  }
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
      if (segments.length >= 2 &&
          segments[1].endsWith('.git') &&
          segments[1].length > 4) {
        segments[1] = segments[1].substring(0, segments[1].length - 4);
      }

      final extension = p.extension(relativePath).toLowerCase();
      final isRaw = imageExtensions.contains(extension);
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

/// Extracts a `.tar.gz` file from [tarball] to [destination].
Future extractTarGz(List<int> tarball, String destination) async {
  log.fine('Extracting .tar.gz stream to $destination.');
  final decompressed = GZipCodec().decode(tarball);
  final reader = TarReader(Stream.fromIterable([decompressed]));
  while (await reader.moveNext()) {
    final entry = reader.current;
    final path = p.join(destination, entry.name);
    if (!p.isWithin(destination, path)) {
      throw ArgumentError('"${entry.name}" is outside of the archive.');
    }
    await File(path).parent.create(recursive: true);
    if (entry.header.linkName != null) {
      final target = p.relative(entry.header.linkName, from: path);
      if (p.isWithin(destination, target)) {
        await Link(path).create(target);
      }
      if (!p.isWithin(destination, target)) {
        throw ArgumentError('"$target" is outside of the archive.');
      }
    } else {
      await entry.contents.pipe(File(path).openWrite());
    }
  }
}

/// Creates a temporary directory and passes its path to [fn].
///
/// Once the [Future] returned by [fn] completes, the temporary directory and
/// all its contents are deleted. [fn] can also return `null`, in which case
/// the temporary directory is deleted immediately afterwards.
///
/// Returns a future that completes to the value that the future returned from
/// [fn] completes to.
Future<T> withTempDir<T>(FutureOr<T> Function(String path) fn) async {
  Directory tempDir;
  try {
    tempDir = await Directory.systemTemp.createTemp('pana_');
    return await fn(tempDir.resolveSymbolicLinksSync());
  } finally {
    tempDir?.deleteSync(recursive: true);
  }
}
