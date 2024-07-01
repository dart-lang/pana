// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:io/ansi.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('pana');

final _key = Object();

Future<R> withLogger<R>(Future<R> Function() fn, {Logger? logger}) => runZoned(
      fn,
      zoneValues: {_key: logger},
    );

Logger get log => (Zone.current[_key] as Logger?) ?? _log;

void initializePanaLogging({bool isJson = false}) {
  if (isJson) {
    Logger.root.onRecord.listen((log) {
      final map = {
        if (log.loggerName.isNotEmpty) 'logName': log.loggerName,
        'level': log.level.name,
        'message': log.message,
        if (log.error != null) 'error': log.error.toString(),
        if (log.stackTrace != null) 'stackTrace': log.stackTrace.toString(),
      };

      stderr.writeln(json.encode(map));
    });
  } else {
    Logger.root.onRecord.listen(_logWriter);
  }
}

void _logWriter(LogRecord record) {
  var wroteHeader = false;

  final output = <String>[];
  final prefix = '${record.time} ${record.level.name}:';
  final emptyPrefix = ' ' * prefix.length;
  void printLinesWithPrefix(String lines) {
    for (final line in lines.split('\n')) {
      final currentPrefix = wroteHeader ? emptyPrefix : prefix;
      output.add('$currentPrefix $line');
      wroteHeader = true;
    }
  }

  printLinesWithPrefix(record.message);
  final e = record.error;
  if (e != null) {
    printLinesWithPrefix(e.toString());
    final st = record.stackTrace;
    if (st != null) {
      printLinesWithPrefix(st.toString());
    }
  }

  overrideAnsiOutput(stderr.supportsAnsiEscapes, () {
    stderr.writeln(darkGray.wrap(output.join('\n')));
  });
}
