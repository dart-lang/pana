// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart' show StreamGroup;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'logging.dart';

Stream<String> _byteStreamSplit(Stream<List<int>> stream) =>
    stream.transform(systemEncoding.decoder).transform(const LineSplitter());

final _timeout = const Duration(minutes: 2);
final _maxLines = 100000;

ProcessResult runProcSync(List<String> arguments,
    {String workingDirectory, Map<String, String> environment}) {
  log.fine('Running `${[...arguments].join(' ')}`...');
  return Process.runSync(
    arguments.first,
    arguments.skip(1).toList(),
    workingDirectory: workingDirectory,
    environment: environment,
  );
}

Future<ProcessResult> runProc(
  List<String> arguments, {
  String workingDirectory,
  Map<String, String> environment,
  Duration timeout,
  bool deduplicate = false,
}) async {
  log.info('Running `${[...arguments].join(' ')}`...');
  var process = await Process.start(arguments.first, arguments.skip(1).toList(),
      workingDirectory: workingDirectory, environment: environment);

  var stdoutLines = <String>[];
  var stderrLines = <String>[];

  bool killed;
  String killMessage;

  void killProc(String message) {
    if (killed != true) {
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

  var items = await Future.wait(<Future<Object>>[
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

ProcessResult handleProcessErrors(ProcessResult result) {
  if (result.exitCode != 0) {
    if (result.exitCode == 69) {
      // could be a pub error. Let's try to parse!
      var lines = LineSplitter.split(result.stderr as String)
          .where((l) => l.startsWith('ERR '))
          .join('\n');
      if (lines.isNotEmpty) {
        throw Exception(lines);
      }
    }

    throw Exception('Problem running proc: exit code - ' +
        [result.exitCode, result.stdout, result.stderr]
            .map((e) => e.toString().trim())
            .join('<***>'));
  }
  return result;
}

/// Executes [body] and returns with the first clean or the last failure result.
Future<ProcessResult> retryProc(
  Future<ProcessResult> Function() body, {
  bool Function(ProcessResult pr) shouldRetry = _defaultShouldRetry,
  int maxAttempt = 3,
  Duration sleep = const Duration(seconds: 1),
}) async {
  ProcessResult result;
  for (var i = 1; i <= maxAttempt; i++) {
    try {
      result = await body();
      if (!shouldRetry(result)) {
        break;
      }
    } catch (e, st) {
      if (i < maxAttempt) {
        log.info('Async operation failed (attempt: $i of $maxAttempt).', e, st);
        await Future.delayed(sleep);
        continue;
      }
      rethrow;
    }
  }
  return result;
}

bool _defaultShouldRetry(ProcessResult pr) => pr.exitCode != 0;

Stream<String> listFiles(String directory,
    {String endsWith, bool deleteBadExtracted = false}) {
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

String prettyJson(obj) {
  try {
    return const JsonEncoder.withIndent(' ').convert(obj);
  } on JsonUnsupportedObjectError catch (e) {
    dynamic error = e;

    while (error is JsonUnsupportedObjectError) {
      final jsError = error as JsonUnsupportedObjectError;
      log.severe(
        '${jsError.unsupportedObject} - (${jsError.unsupportedObject.runtimeType}).'
        ' Nested cause: ${jsError.cause}',
        error,
        jsError.stackTrace,
      );

      error = error.cause;
    }
    rethrow;
  }
}

Object sortedJson(obj) {
  var fullJson = json.decode(json.encode(obj));
  return _toSortedMap(fullJson);
}

dynamic _toSortedMap(Object item) {
  if (item is Map) {
    return SplayTreeMap<String, Object>.fromIterable(item.keys,
        value: (k) => _toSortedMap(item[k]));
  } else if (item is List) {
    return item.map(_toSortedMap).toList();
  } else {
    return item;
  }
}

Map<String, Object> yamlToJson(String yamlContent) {
  if (yamlContent == null) {
    return null;
  }
  var yamlMap = loadYaml(yamlContent) as YamlMap;

  // A bit paranoid, but I want to make sure this is valid JSON before we got to
  // the encode phase.
  return sortedJson(json.decode(json.encode(yamlMap))) as Map<String, Object>;
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

/// A merged stream of all signals that tell the test runner to shut down
/// gracefully.
///
/// Signals will only be captured as long as this has an active subscription.
/// Otherwise, they'll be handled by Dart's default signal handler, which
/// terminates the program immediately.
Stream<ProcessSignal> getSignals() => Platform.isWindows
    ? ProcessSignal.sigint.watch()
    : StreamGroup.merge(
        [ProcessSignal.sigterm.watch(), ProcessSignal.sigint.watch()]);

/// Returns the ratio of non-ASCII runes (Unicode characters) in a given text:
/// (number of runes that are non-ASCII) / (total number of character runes).
///
/// The return value is between [0.0 - 1.0].
double nonAsciiRuneRatio(String text) {
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

/// Returns common file name candidates for [base] (specified without any extension).
List<String> textFileNameCandidates(String base) {
  return <String>[
    base,
    '$base.md',
    '$base.markdown',
    '$base.mkdown',
    '$base.txt',
  ];
}
