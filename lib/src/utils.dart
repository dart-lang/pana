// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'logging.dart';

Stream<String> _byteStreamSplit(Stream<List<int>> stream) =>
    stream.transform(systemEncoding.decoder).transform(const LineSplitter());

final _timeout = const Duration(minutes: 2);
final _maxLines = 100000;

Future<ProcessResult> runProc(
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  Duration? timeout,
  bool deduplicate = false,
}) async {
  log.info('Running `${[...arguments].join(' ')}`...');
  var process = await Process.start(arguments.first, arguments.skip(1).toList(),
      workingDirectory: workingDirectory, environment: environment);

  var stdoutLines = <String>[];
  var stderrLines = <String>[];

  var killed = false;
  String? killMessage;

  void killProc(String message) {
    if (!killed) {
      killMessage = message;
      log.severe('Killing `${arguments.join(' ')}` $killMessage');
      killed = process.kill();
      log.info('killed `${arguments.join(' ')}` - $killed');
    }
  }

  timeout ??= _timeout;
  var timer = Timer(timeout, () {
    killProc('Exceeded timeout of $timeout');
  });

  var items = await Future.wait(<Future>[
    process.exitCode,
    _byteStreamSplit(process.stdout).forEach((outLine) {
      // TODO: Remove deduplication when https://github.com/dart-lang/sdk/issues/36062 gets fixed
      if (deduplicate && stdoutLines.contains(outLine)) {
        return;
      }
      stdoutLines.add(outLine);
      // Uncomment to debug long execution
      // log.severe(outLine);
      if (stdoutLines.length > _maxLines) {
        killProc('STDOUT exceeded $_maxLines lines.');
      }
    }),
    _byteStreamSplit(process.stderr).forEach((errLine) {
      // TODO: Remove deduplication when https://github.com/dart-lang/sdk/issues/36062 gets fixed
      if (deduplicate && stderrLines.contains(errLine)) {
        return;
      }
      stderrLines.add(errLine);
      // Uncomment to debug long execution
      // log.severe(errLine);
      if (stderrLines.length > _maxLines) {
        killProc('STDERR exceeded $_maxLines lines.');
      }
    })
  ]);

  timer.cancel();

  final exitCode = items[0] as int;
  if (killed == true) {
    return ProcessResult(
        process.pid,
        exitCode,
        stdoutLines.take(1000).join('\n'),
        [
          if (killMessage != null) killMessage,
          ...stderrLines.take(1000),
        ].join('\n'));
  }

  return ProcessResult(
      process.pid, exitCode, stdoutLines.join('\n'), stderrLines.join('\n'));
}

Stream<String> listFiles(String directory,
    {String? endsWith, bool deleteBadExtracted = false}) {
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
dynamic sortedJson(obj) {
  var fullJson = json.decode(json.encode(obj));
  return _toSortedMap(fullJson);
}

dynamic _toSortedMap(dynamic item) {
  if (item is Map) {
    return SplayTreeMap<String, dynamic>.fromIterable(item.keys,
        value: (k) => _toSortedMap(item[k]));
  } else if (item is List) {
    return item.map(_toSortedMap).toList();
  } else {
    return item;
  }
}

Map<String, dynamic>? yamlToJson(String? yamlContent) {
  if (yamlContent == null) {
    return null;
  }
  var yamlMap = loadYaml(yamlContent) as YamlMap;

  // A bit paranoid, but I want to make sure this is valid JSON before we got to
  // the encode phase.
  return sortedJson(json.decode(json.encode(yamlMap))) as Map<String, dynamic>;
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
