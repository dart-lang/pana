// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart' as log;
import 'package:pana/pana.dart';

final _gray = '\u001b[1;30m';
final _none = '\u001b[0m';

String gray(text) => "$_gray$text$_none";

main(List<String> arguments) async {
  log.Logger.root.level = log.Level.ALL;
  log.Logger.root.onRecord.listen((record) {
    var wroteHeader = false;

    var msg = LineSplitter
        .split([record.message, record.error, record.stackTrace]
            .where((e) => e != null)
            .join('\n'))
        .map((l) {
      String prefix;
      if (wroteHeader) {
        prefix = '';
      } else {
        wroteHeader = true;
        prefix = record.level.toString();
      }
      return "${prefix.padRight(10)} ${l}";
    }).join('\n');

    stderr.writeln(gray(msg));
  });

  var pkg = arguments.first;

  String version;
  if (arguments.length > 1) {
    version = arguments[1];
  }

  var tempDir = Directory.systemTemp
      .createTempSync('pana.${new DateTime.now().millisecondsSinceEpoch}.');

  // Critical to make sure analyzer paths align well
  var tempPath = await tempDir.resolveSymbolicLinks();

  try {
    try {
      PackageAnalyzer analyzer = new PackageAnalyzer(pubCacheDir: tempPath);
      var summary = await analyzer.inspectPackage(pkg, version: version);

      print(prettyJson(summary));
    } catch (e, stack) {
      stderr.writeln("Problem with pkg $pkg ($version)");
      stderr.writeln(e);
      stderr.writeln(stack);
      exitCode = 1;
    }
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
