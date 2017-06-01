// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Stream<String> byteStreamSplit(Stream<List<int>> stream) =>
    stream.transform(SYSTEM_ENCODING.decoder).transform(const LineSplitter());

final _timeout = const Duration(minutes: 1);
final _maxLines = 100000;

Future<ProcessResult> runProc(String executable, List<String> arguments,
    {String workingDirectory, Map<String, String> environment}) async {
  var process = await Process.start(executable, arguments,
      workingDirectory: workingDirectory, environment: environment);

  var stdoutLines = <String>[];
  var stderrLines = <String>[];

  bool killed;
  String killMessage;

  void killProc(String message) {
    if (killed != true) {
      killMessage = message;
      stderr.writeln("Killing $process");
      stderr.writeln("  $message");
      killed = process.kill();
      stderr.writeln("  killed? - $killed");
    }
  }

  var timer = new Timer(_timeout, () {
    killProc("Exceeded timeout of $_timeout");
  });

  var items = await Future.wait(<Future<Object>>[
    process.exitCode,
    byteStreamSplit(process.stdout).forEach((outLine) {
      stdoutLines.add(outLine);
      // Uncomment to debug long execution
      // stderr.writeln(outLine);
      if (stdoutLines.length > _maxLines) {
        killProc("STDOUT exceeded $_maxLines lines.");
      }
    }),
    byteStreamSplit(process.stderr).forEach((errLine) {
      stderrLines.add(errLine);
      // Uncomment to debug long execution
      // stderr.writeln(errLine);
      if (stderrLines.length > _maxLines) {
        killProc("STDERR exceeded $_maxLines lines.");
      }
    })
  ]);

  timer.cancel();

  var exitCode = items[0] as int;
  if (killed == true) {
    assert(exitCode < 0);

    stdoutLines.insert(0, killMessage);
    stderrLines.insert(0, killMessage);

    return new ProcessResult(process.pid, exitCode,
        stdoutLines.take(1000).join('\n'), stderrLines.take(1000).join('\n'));
  }

  return new ProcessResult(
      process.pid, items[0], stdoutLines.join('\n'), stderrLines.join('\n'));
}

ProcessResult handleProcessErrors(ProcessResult result) {
  if (result.exitCode != 0) {
    if (result.exitCode == 69) {
      // could be a pub error. Let's try to parse!
      var lines = LineSplitter
          .split(result.stderr)
          .where((l) => l.startsWith("ERR "))
          .join('\n');
      if (lines.isNotEmpty) {
        throw lines;
      }
    }

    throw "Problem running proc: exit code - " +
        [result.exitCode, result.stdout, result.stderr]
            .map((e) => e.toString().trim())
            .join('<***>');
  }
  return result;
}

Future<List<String>> listFiles(String directory, {String endsWith}) {
  Directory dir = new Directory(directory);
  return dir
      .list(recursive: true)
      .where((fse) => fse is File)
      .map((fse) => fse.path)
      .where((path) => endsWith == null || path.endsWith(endsWith))
      .map((path) => p.relative(path, from: directory))
      .toList();
}

String prettyJson(obj) => const JsonEncoder.withIndent(' ').convert(obj).trim();

Object sortedJson(obj) {
  var fullJson = JSON.decode(JSON.encode(obj));
  return _toSortedMap(fullJson);
}

_toSortedMap(Object item) {
  if (item is Map) {
    return new SplayTreeMap<String, Object>.fromIterable(item.keys,
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
  return sortedJson(JSON.decode(JSON.encode(yamlMap)));
}
