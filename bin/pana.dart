import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

import 'package:pana/pana.dart';

// http://linux.die.net/include/sysexits.h
// #define EX_SOFTWARE	70	/* internal software error */
const _internalError = 77;

main(List<String> args) {
  hierarchicalLoggingEnabled = true;

  // get a length that's 1 + longest level name
  var logHeaderLength = Level.LEVELS
      .fold(0, (length, level) => math.max(length, level.name.length + 1));

  Logger.root.onRecord.listen((item) {
    stderr.writeln('${item.level.name.padRight(logHeaderLength, ' ')}' +
        LineSplitter.split(item.message).join("\n${' ' * logHeaderLength}"));
  });

  Chain.capture(() async {
    for (var item in args) {
      var summary = await run(item);
      print(const JsonEncoder.withIndent(' ').convert(summary));
    }
  }, onError: (error, Chain chain) {
    print(error);
    print(chain.terse);
    exitCode = _internalError;
  });
}
