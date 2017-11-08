// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'logging.dart';
import 'utils.dart';

/// Returns a non-null Directory instance only if it is able to download and
/// extract the direct package dependency. On any failure it clears the temp
/// directory, otherwise it is the caller's responsibility to delete it.
Future<Directory> downloadPackage(String package, String version) async {
  final temp = await Directory.systemTemp.createTemp('pana-');
  final dir = new Directory(await temp.resolveSymbolicLinks());
  try {
    final uri = new Uri.https(
        'pub.dartlang.org', '/packages/$package/versions/$version.tar.gz');
    final bytes = await http.readBytes(uri);
    final archiveFileName = path.join(dir.path, '$package-$version.tar.gz');
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
