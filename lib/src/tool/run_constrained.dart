// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:pana/src/logging.dart';

final _timeout = const Duration(minutes: 2);
const _maxOutputBytes = 10 * 1024 * 1024; // 10 MiB
const _maxOutputLinesWhenKilled = 1000;

/// Runs the [arguments] as a program|script + its argument list.
///
/// Kills the process after [timeout] (2 minutes if not specified).
/// Kills the process if its output is more than [maxOutputBytes] (10 MiB if not specified).
///
/// If the process is killed, it returns only the first 1000 lines of both `stdout` and `stderr`.
///
/// When [throwOnError] is `true`, non-zero exit codes will throw a [ToolException].
Future<PanaProcessResult> runConstrained(
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  Duration? timeout,
  int? maxOutputBytes,
  bool throwOnError = false,
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
  late PanaProcessResult result;
  if (killed) {
    final encoding = systemEncoding;
    result = PanaProcessResult(
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
  } else {
    result = PanaProcessResult(
      process.pid,
      exitCode,
      stdoutLines,
      stderrLines,
      wasTimeout: wasTimeout,
      wasOutputExceeded: wasOutputExceeded,
    );
  }
  if (throwOnError && result.wasError) {
    throw ToolException.fromProcessResult(result);
  }
  return result;
}

class ToolException implements Exception {
  final String message;
  final ProcessOutput? stderr;

  ToolException(this.message, [this.stderr]);

  factory ToolException.fromProcessResult(PanaProcessResult result) {
    final fullOutput = [
      result.exitCode.toString(),
      result.stdout.asString,
      result.stderr.asString,
    ].map((e) => e.trim()).join('\n<***>\n');
    return ToolException(fullOutput, result.stderr);
  }

  @override
  String toString() {
    return 'Exception: $message';
  }
}

class PanaProcessResult {
  final int pid;
  final int exitCode;
  final ProcessOutput stdout;
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
        stdout = stdout is ProcessOutput
            ? stdout
            : ProcessOutput.from(stdout, encoding: encoding),
        stderr = stderr is ProcessOutput
            ? stderr
            : ProcessOutput.from(stderr, encoding: encoding);

  PanaProcessResult change({
    ProcessOutput? stderr,
  }) =>
      PanaProcessResult(
        pid,
        exitCode,
        stdout,
        stderr ?? this.stderr,
        wasTimeout: wasTimeout,
        wasOutputExceeded: wasOutputExceeded,
        wasError: wasError,
      );

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

/// The output of a process as String or byte stream.
abstract class ProcessOutput {
  factory ProcessOutput.from(Object value, {Encoding? encoding}) {
    encoding ??= systemEncoding;
    if (value is List<List<int>>) {
      return _ChunksProcessOutput(value, encoding);
    }
    if (value is String) {
      return _StringProcessOutput(value);
    }
    throw ArgumentError('Invalid ProcessOutput argument: ${value.runtimeType}');
  }

  String get asString;

  @override
  String toString();
}

class _StringProcessOutput implements ProcessOutput {
  @override
  final String asString;
  _StringProcessOutput(this.asString);

  @override
  String toString() => asString;
}

class _ChunksProcessOutput implements ProcessOutput {
  final List<List<int>> _chunks;
  final Encoding _encoding;
  _ChunksProcessOutput(this._chunks, this._encoding);

  @override
  late final asString = _encoding.decode(_asBytes);

  late final _asBytes = _chunks
      .fold<BytesBuilder>(BytesBuilder(), (bb, chunk) => bb..add(chunk))
      .toBytes();

  @override
  String toString() => asString;
}
