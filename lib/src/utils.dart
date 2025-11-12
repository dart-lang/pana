// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:retry/retry.dart';
import 'package:yaml/yaml.dart';

import 'logging.dart';

Stream<String> listFiles(
  String directory, {
  String? endsWith,
  bool deleteBadExtracted = false,
}) {
  var dir = Directory(directory);
  return dir
      .list(recursive: true)
      .where((fse) => fse is File)
      .where((fse) {
        if (deleteBadExtracted) {
          var segments = p.split(fse.path);
          if (segments.last.startsWith('._')) {
            log.info('Deleting invalid file: `${fse.path}`.');
            fse.deleteSync();
            return false;
          }
        }
        return true;
      })
      .map((fse) => fse.path)
      .where((path) => endsWith == null || path.endsWith(endsWith))
      .map((path) => p.relative(path, from: directory));
}

/// Paths to all files matching `$packageDir/lib/**/*.dart`.
///
/// Paths are returned relative to `lib/`.
List<String> dartFilesFromLib(String packageDir) {
  final libDir = Directory(p.join(packageDir, 'lib'));
  final libDirExists = libDir.existsSync();
  final dartFiles = libDirExists
      ? libDir
            .listSync(recursive: true)
            .where((e) => e is File && e.path.endsWith('.dart'))
            .map((f) => p.relative(f.path, from: libDir.path))
            .toList()
      : <String>[];

  // Sort to make the order of files and the reported events deterministic.
  dartFiles.sort();
  return dartFiles;
}

@visibleForTesting
Object? sortedJson(Object? obj) {
  final fullJson = json.decode(json.encode(obj));
  return _toSortedMap(fullJson);
}

Object? _toSortedMap(Object? item) {
  if (item is Map) {
    return SplayTreeMap<String, Object?>.fromIterable(
      item.keys,
      value: (k) => _toSortedMap(item[k]),
    );
  } else if (item is List) {
    return item.map(_toSortedMap).toList();
  } else {
    return item;
  }
}

Map<String, Object?>? yamlToJson(String? yamlContent) {
  if (yamlContent == null) {
    return null;
  }
  var yamlMap = loadYaml(yamlContent);
  if (yamlMap is! Map) {
    return null;
  }

  // A bit paranoid, but I want to make sure this is valid JSON before we got to
  // the encode phase.
  return sortedJson(json.decode(json.encode(yamlMap))) as Map<String, Object?>;
}

/// Returns the list of directories to focus on (e.g. bin, lib) - if they exist.
Future<List<String>> listFocusDirs(String packageDir) async {
  final dirs = <String>[];
  for (final dir in ['bin', 'lib']) {
    final path = p.join(packageDir, dir);
    if ((await FileSystemEntity.type(path)) != FileSystemEntityType.directory) {
      continue;
    }
    if (await listFiles(path, endsWith: '.dart').isEmpty) {
      continue;
    }
    dirs.add(dir);
  }
  return dirs;
}

/// Returns the ratio of non-ASCII runes (Unicode characters) in a given text:
/// (number of runes that are non-ASCII) / (total number of character runes).
///
/// The return value is between [0.0 - 1.0].
double nonAsciiRuneRatio(String? text) {
  if (text == null || text.isEmpty) {
    return 0.0;
  }
  final totalPrintable = text.runes.where((r) => r > 32).length;
  if (totalPrintable == 0) {
    return 0.0;
  }
  final nonAscii = text.runes.where((r) => r >= 128).length;
  return nonAscii / totalPrintable;
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
  Directory? tempDir;
  try {
    tempDir = await Directory.systemTemp.createTemp('pana_');
    return await fn(tempDir.resolveSymbolicLinksSync());
  } finally {
    tempDir?.deleteSync(recursive: true);
  }
}

Future<void> copyDir(String from, String to) async {
  await for (final fse in Directory(from).list(recursive: true)) {
    final relativePath = p.relative(fse.path, from: from);
    // The following file is used by `git-fsmonitor` and copying is blocked.
    // https://git-scm.com/docs/git-fsmonitor--daemon
    if (relativePath == '.git/fsmonitor--daemon.ipc') {
      continue;
    }
    if (fse is File) {
      final newFile = File(p.join(to, relativePath));
      await newFile.parent.create(recursive: true);
      await fse.copy(newFile.path);
    } else if (fse is Link) {
      final linkTarget = await fse.target();
      final newLink = Link(p.join(to, relativePath));
      await newLink.parent.create(recursive: true);
      await newLink.create(linkTarget);
    }
  }
}

Future<String> getVersionListing(String package, {Uri? pubHostedUrl}) async {
  var url = (pubHostedUrl ?? Uri.parse('https://pub.dartlang.org'))
      .normalizePath();
  // If we have a path of only '/'
  if (url.path == '/') {
    url = url.replace(path: '');
  }
  // If there is a path, and it doesn't end in a slash we normalize to slash
  if (url.path.isNotEmpty && !url.path.endsWith('/')) {
    url = url.replace(path: '${url.path}/');
  }
  url = url.resolve('api/packages/$package');
  log.fine('Downloading: $url');

  return await retry(
    () async {
      final rs = await http.get(url).timeout(const Duration(seconds: 20));
      if (rs.statusCode == 200) {
        return rs.body;
      }
      final message = '"$url" returned with status code ${rs.statusCode}.';
      if (rs.statusCode >= 400 && rs.statusCode < 500) {
        // does not retry on errors
        throw Exception(message);
      } else {
        throw _RetryException(message);
      }
    },
    onRetry: (e) =>
        e is _RetryException || e is IOException || e is TimeoutException,
  );
}

class _RetryException implements Exception {
  final String _message;
  _RetryException(this._message);

  @override
  String toString() => _message;
}
