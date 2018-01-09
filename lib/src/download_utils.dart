// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'logging.dart';
import 'utils.dart';

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
  try {
    final uri = Uri.parse(repository);
    final segments = new List<String>.from(uri.pathSegments);
    while (segments.isNotEmpty && segments.last.isEmpty) {
      segments.removeLast();
    }

    if (repository.startsWith('https://github.com/') ||
        repository.startsWith('https://gitlab.com/')) {
      if (segments.length < 2) {
        return null;
      } else if (segments.length == 2) {
        return p.join(repository, 'blob/master', relativePath);
      } else if (segments[2] == 'tree' || segments[2] == 'blob') {
        segments[2] = 'blob';
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

Future<bool> isExistingUrl(String url) async {
  try {
    log.info('Checking URL $url...');
    final rs = await http.get(url).timeout(const Duration(seconds: 10));
    return rs.statusCode == 200;
  } catch (e) {
    log.warning('Check of URL $url failed', e);
  }
  return false;
}
