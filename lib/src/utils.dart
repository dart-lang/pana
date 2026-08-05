// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
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
  return _toSortedMap(obj);
}

Object? _toSortedMap(Object? item) {
  if (item is Map) {
    final sortedKeys = item.keys.map((k) => k.toString()).toList()..sort();
    final result = <String, Object?>{};
    for (final k in sortedKeys) {
      result[k] = _toSortedMap(item[k]);
    }
    return result;
  } else if (item is List) {
    return item.map(_toSortedMap).toList();
  } else {
    return item;
  }
}

/// Converts a YAML-formatted string [yamlContent] into a JSON-compatible map
/// with alphabetically sorted keys.
///
/// Returns `null` if [yamlContent] is `null` or if the parsed YAML root is not a [Map].
///
/// Throws a [FormatException] if the YAML contains cyclic references, exceeds
/// the maximum allowed nesting depth ([maxDepth], default `64`), or exceeds the
/// maximum allowed node count ([maxNodes], default `10000`) during expansion.
///
/// Throws a [YamlException] if the YAML syntax is invalid.
///
/// Performance: Runs in $O(N \log K)$ time where $N$ is the number of expanded
/// nodes (capped by [maxNodes]) and $K$ is the average number of keys per map.
Map<String, Object?>? yamlToJson(
  String? yamlContent, {
  int maxDepth = 64,
  int maxNodes = 10000,
}) {
  if (yamlContent == null) {
    return null;
  }
  var yamlMap = loadYaml(yamlContent);
  if (yamlMap is! Map) {
    return null;
  }

  final converter = _YamlConverter(maxDepth: maxDepth, maxNodes: maxNodes);
  final converted = converter.convert(yamlMap, 0);
  if (converted is! Map<String, Object?>) {
    return null;
  }
  return converted;
}

final class _YamlConverter {
  final int maxDepth;
  final int maxNodes;
  int _nodeCount = 0;
  final Set<Object> _ancestors = Set<Object>.identity();

  _YamlConverter({required this.maxDepth, required this.maxNodes});

  Object? convert(Object? node, int depth) {
    if (depth > maxDepth) {
      throw const FormatException(
        'YAML structure exceeds maximum allowed depth.',
      );
    }
    _nodeCount++;
    if (_nodeCount > maxNodes) {
      throw const FormatException(
        'YAML structure exceeds maximum allowed node count.',
      );
    }

    if (node is YamlScalar) {
      return _convertScalar(node.value);
    } else if (node is YamlMap) {
      if (!_ancestors.add(node)) {
        throw const FormatException('Cyclic reference detected in YAML.');
      }
      try {
        final entries = [
          for (final entry in node.nodes.entries)
            MapEntry(_convertKey(entry.key), entry.value),
        ]..sort((a, b) => a.key.compareTo(b.key));
        final result = <String, Object?>{};
        for (final entry in entries) {
          result[entry.key] = convert(entry.value, depth + 1);
        }
        return result;
      } finally {
        _ancestors.remove(node);
      }
    } else if (node is YamlList) {
      if (!_ancestors.add(node)) {
        throw const FormatException('Cyclic reference detected in YAML.');
      }
      try {
        final result = <Object?>[];
        for (final item in node.nodes) {
          result.add(convert(item, depth + 1));
        }
        return result;
      } finally {
        _ancestors.remove(node);
      }
    } else if (node is Map) {
      if (!_ancestors.add(node)) {
        throw const FormatException('Cyclic reference detected in YAML.');
      }
      try {
        final entries = [
          for (final entry in node.entries)
            MapEntry(_convertKey(entry.key), entry.value),
        ]..sort((a, b) => a.key.compareTo(b.key));
        final result = <String, Object?>{};
        for (final entry in entries) {
          result[entry.key] = convert(entry.value, depth + 1);
        }
        return result;
      } finally {
        _ancestors.remove(node);
      }
    } else if (node is List) {
      if (!_ancestors.add(node)) {
        throw const FormatException('Cyclic reference detected in YAML.');
      }
      try {
        final result = <Object?>[];
        for (final item in node) {
          result.add(convert(item, depth + 1));
        }
        return result;
      } finally {
        _ancestors.remove(node);
      }
    } else {
      return _convertScalar(node);
    }
  }

  String _convertKey(Object? key) {
    if (key is YamlScalar) {
      key = key.value;
    }
    if (key == null) {
      return 'null';
    }
    if (key is String || key is num || key is bool) {
      return key.toString();
    }
    throw FormatException('Unsupported key type in YAML: ${key.runtimeType}');
  }

  Object? _convertScalar(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    return value.toString();
  }
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

final _binOrLibSet = {'bin', 'lib'};
final _topLevelTargets = {'pubspec.yaml'};

/// Returns true wether a [path] inside the package is an analysis target
/// (primarily the  `bin/` and `lib/` directories).
bool isAnalysisTarget(String path) {
  if (_topLevelTargets.contains(path)) {
    return true;
  }
  // filter path prefixes
  final parts = p.split(path);
  return parts.isNotEmpty && _binOrLibSet.contains(parts.first);
}
