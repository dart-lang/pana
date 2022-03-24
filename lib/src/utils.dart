// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:retry/retry.dart';
import 'package:yaml/yaml.dart';

import 'logging.dart';
import 'sdk_env.dart' show ToolException;

final _timeout = const Duration(minutes: 2);
const _maxOutputBytes = 10 * 1024 * 1024; // 10 MiB
const _maxOutputLinesWhenKilled = 1000;

/// Runs the [arguments] as a program|script + its argument list.
///
/// Kills the process after [timeout] (2 minutes if not specified).
/// Kills the process if its output is more than [maxOutputBytes] (10 MiB if not specified).
///
/// If the process is killed, it returns only the first 1000 lines of both `stdout` and `stderr`.
Future<PanaProcessResult> runProc(
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  Duration? timeout,
  int? maxOutputBytes,
}) async {
  timeout ??= _timeout;
  maxOutputBytes ??= _maxOutputBytes;

  log.info('Running `${[...arguments].join(' ')}`...');
  var process = await Process.start(arguments.first, arguments.skip(1).toList(),
      workingDirectory: workingDirectory, environment: environment);

  var stdoutLines = <List<int>>[];
  var stderrLines = <List<int>>[];
  var remainingBytes = maxOutputBytes;

  var killed = false;
  var wasTimeout = false;
  var wasOutputExceeded = false;
  String? killMessage;

  void killProc(String message) {
    if (!killed) {
      killMessage = message;
      log.severe('Killing `${arguments.join(' ')}` $killMessage');
      killed = process.kill(ProcessSignal.sigkill);
      log.info('killed `${arguments.join(' ')}` - $killed');
    }
  }

  var timer = Timer(timeout, () {
    wasTimeout = true;
    killProc('Exceeded timeout of $timeout');
  });

  var items = await Future.wait(<Future>[
    process.exitCode,
    process.stdout.forEach((outLine) {
      stdoutLines.add(outLine);
      remainingBytes -= outLine.length;
      if (remainingBytes < 0) {
        wasOutputExceeded = true;
        killProc('Output exceeded $maxOutputBytes bytes.');
      }
    }),
    process.stderr.forEach((errLine) {
      stderrLines.add(errLine);
      remainingBytes -= errLine.length;
      if (remainingBytes < 0) {
        wasOutputExceeded = true;
        killProc('Output exceeded $maxOutputBytes bytes.');
      }
    })
  ]);

  timer.cancel();

  final exitCode = items[0] as int;
  if (killed) {
    final encoding = systemEncoding;
    return PanaProcessResult(
      process.pid,
      exitCode,
      stdoutLines
          .map(encoding.decode)
          .expand(const LineSplitter().convert)
          .take(_maxOutputLinesWhenKilled)
          .join('\n'),
      [
        if (killMessage != null) killMessage,
        ...stderrLines
            .map(encoding.decode)
            .expand(const LineSplitter().convert)
            .take(_maxOutputLinesWhenKilled),
      ].join('\n'),
      wasTimeout: wasTimeout,
      wasOutputExceeded: wasOutputExceeded,
      wasError: true,
    );
  }

  return PanaProcessResult(
    process.pid,
    exitCode,
    stdoutLines,
    stderrLines,
    wasTimeout: wasTimeout,
    wasOutputExceeded: wasOutputExceeded,
  );
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

Future<String> getVersionListing(String package, {Uri? pubHostedUrl}) async {
  final url = (pubHostedUrl ?? Uri.parse('https://pub.dartlang.org'))
      .resolve('/api/packages/$package');
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
        throw _RetryExpception(message);
      }
    },
    onRetry: (e) =>
        e is _RetryExpception || e is IOException || e is TimeoutException,
  );
}

class _RetryExpception implements Exception {
  final String _message;
  _RetryExpception(this._message);

  @override
  String toString() => _message;
}

/// The output of a process as String or byte stream.
abstract class ProcessOutput {
  factory ProcessOutput.from(Object value, {Encoding? encoding}) {
    encoding ??= systemEncoding;
    if (value is List<List<int>>) {
      return _ChunksProcessOutput(value, encoding);
    }
    if (value is String) {
      return _StringProcessOutput(value, encoding);
    }
    throw ArgumentError('Invalid ProcessOutput argument: ${value.runtimeType}');
  }

  String get asString;
  List<int> get asBytes;

  @override
  String toString();
}

class _StringProcessOutput implements ProcessOutput {
  @override
  final String asString;
  final Encoding _encoding;
  _StringProcessOutput(this.asString, this._encoding);

  @override
  late final asBytes = _encoding.encode(asString);

  @override
  String toString() => asString;
}

class _ChunksProcessOutput implements ProcessOutput {
  final List<List<int>> _chunks;
  final Encoding _encoding;
  _ChunksProcessOutput(this._chunks, this._encoding);

  @override
  late final asString = _chunks.map(_encoding.decode).join();

  @override
  late final List<int> asBytes = _chunks
      .fold<BytesBuilder>(BytesBuilder(), (bb, chunk) => bb..add(chunk))
      .toBytes();

  @override
  String toString() => asString;
}

class PanaProcessResult implements ProcessResult {
  @override
  final int pid;
  @override
  final int exitCode;
  @override
  final ProcessOutput stdout;
  @override
  final ProcessOutput stderr;
  final bool wasTimeout;
  final bool wasOutputExceeded;
  final bool _wasError;

  PanaProcessResult(
    this.pid,
    this.exitCode,
    Object stdout,
    Object stderr, {
    this.wasTimeout = false,
    this.wasOutputExceeded = false,
    bool wasError = false,
    Encoding? encoding,
  })  : _wasError = wasError,
        stdout = ProcessOutput.from(stdout, encoding: encoding),
        stderr = ProcessOutput.from(stderr, encoding: encoding);

  /// True if the process completed with some error, false if successful.
  late final wasError =
      _wasError || exitCode != 0 || wasTimeout || wasOutputExceeded;

  /// Returns the line-concatened output of `stdout` and `stderr`
  /// (both converted to [String]), and the final output trimmed.
  String get asJoinedOutput {
    return [
      stdout.asString.trim(),
      stderr.asString.trim(),
    ].join('\n').trim();
  }

  /// Return the line-concatenated output of `stdout` and `stderr`
  /// (both converted to [String]), with limits on individual line
  /// lengths and total lines. Total length should not be more than 4KiB.
  String get asTrimmedOutput {
    String trimLine(String line) =>
        line.length > 200 ? '${line.substring(0, 195)}[...]' : line;

    Iterable<String> firstFewLines(String type, String output) sync* {
      if (output.isEmpty) return;
      yield '$type:';
      final lines = const LineSplitter().convert(output);
      if (lines.length <= 10) {
        yield* lines.map(trimLine);
      } else {
        yield* lines.take(10).map(trimLine);
        yield '[${lines.length - 10} more lines]';
      }
    }

    return [
      ...firstFewLines('OUT', stdout.asString.trim()),
      ...firstFewLines('ERR', stderr.asString.trim()),
    ].join('\n').trim();
  }

  /// Parses the output of the process as JSON.
  Map<String, dynamic> parseJson({
    String Function(String value)? transform,
  }) {
    final value =
        transform == null ? asJoinedOutput : transform(asJoinedOutput);
    try {
      return json.decode(value) as Map<String, dynamic>;
    } on FormatException catch (_) {
      throw ToolException(
          'Unable to parse output as JSON:\n\n```\n$asTrimmedOutput\n```\n');
    }
  }
}
