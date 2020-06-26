// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:safe_url_check/safe_url_check.dart';

import 'logging.dart';
import 'utils.dart';

final imageExtensions = <String>{'.gif', '.jpg', '.jpeg', '.png'};

/// Downloads [package] and unpacks it into [destination]
Future<void> downloadPackage(
  String package,
  String version, {
  @required String destination,
  String pubHostedUrl,
}) async {
  // Find URI for the package tar-ball
  final pubHostedUri = Uri.parse(pubHostedUrl ?? 'https://pub.dartlang.org');
  final packageUri = pubHostedUri.replace(
    path: '/packages/$package/versions/$version.tar.gz',
  );
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
    final chmod = await runProc('/bin/chmod', [
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
      final extension = p.extension(relativePath).toLowerCase();
      final isRaw = imageExtensions.contains(extension);
      final typeSegment = isRaw ? 'raw' : 'blob';

      if (segments.length < 2) {
        return null;
      } else if (segments.length == 2) {
        return p.url.join(repository, typeSegment, 'master', relativePath);
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

final String _pathTo7zip = (() {
  return p.join(p.dirname(p.dirname(Platform.resolvedExecutable)), 'lib',
      '_internal', 'pub', 'asset', '7zip', '7za.exe');
})();

String _tarPath = _findTarPath();

/// Find a tar. Prefering system installed tar.
///
/// On linux tar should always be /bin/tar [See FHS 2.3][1]
/// On MacOS it seems to always be /usr/bin/tar.
///
/// [1]: https://refspecs.linuxfoundation.org/FHS_2.3/fhs-2.3.pdf
String _findTarPath() {
  for (final file in ['/bin/tar', '/usr/bin/tar']) {
    if (File(file).existsSync()) {
      return file;
    }
  }
  log.warning(
      'Could not find a system `tar` installed in /bin/tar or /usr/bin/tar, '
      'attempting to use tar from PATH');
  return 'tar';
}

/// Extracts a `.tar.gz` file from [tarball] to [destination].
Future extractTarGz(List<int> tarball, String destination) async {
  log.fine('Extracting .tar.gz stream to $destination.');
  final decompressed = GZipCodec().decode(tarball);

  // We used to stream directly to `tar`,  but that was fragile in certain
  // settings.
  final processResult = await withTempDir((tempDir) async {
    final tarFile = p.join(tempDir, 'archive.tar');
    try {
      File(tarFile).writeAsBytesSync(decompressed);
    } catch (e) {
      // We don't know the error type here: https://dartbug.com/41270
      throw FileSystemException('Could not decompress gz stream $e');
    }
    return (Platform.isWindows)
        ? Process.runSync(_pathTo7zip, ['x', tarFile],
            workingDirectory: destination)
        : Process.runSync(_tarPath, [
            '--extract',
            '--no-same-owner',
            '--no-same-permissions',
            '--directory',
            destination,
            '--file',
            tarFile,
          ]);
  });
  if (processResult.exitCode != 0) {
    throw FileSystemException(
        'Could not un-tar (exit code ${processResult.exitCode}). Error:\n'
        '${processResult.stdout}\n'
        '${processResult.stderr}');
  }
  log.fine('Extracted .tar.gz to $destination. Exit code $exitCode.');
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
