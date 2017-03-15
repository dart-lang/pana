// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart' as log;
import 'package:pana/pana.dart';

final _gray = '\u001b[1;30m';
final _none = '\u001b[0m';

String gray(text) => "$_gray$text$_none";

main(List<String> arguments) async {
  log.Logger.root.level = log.Level.ALL;
  log.Logger.root.onRecord.listen((record) {
    stderr.writeln(
        gray("${record.level.toString().padRight(10)} ${record.message}"));
  });

  var pkg = arguments.first;

  String version;
  if (arguments.length > 1) {
    version = arguments[1];
  }

  var summary = await doIt(pkg, version: version);

  print(prettyJson(summary));
}
