// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/src/mini_sum.dart';
import 'package:pana/src/summary.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;

main() async {
  var dir = new Directory("results");

  var items = dir
      .listSync()
      .where((fse) => fse is File && p.extension(fse.path) == '.json')
      .toList();

  var summaries = items
      .map((fse) => _process((fse as File).readAsStringSync()))
      .where((sum) => sum.pubClean)
      .toList();

  _updateResults(summaries);
}

void _updateResults(List<MiniSum> summaries) {
  var toolDir = new Directory('tool');
  if (!toolDir.existsSync()) {
    toolDir.createSync();
  }

  var file = new File(p.join('tool', 'summaries.tjson'));
  try {
    file.writeAsStringSync(
        summaries.map((m) => m.toJson()).map(JSON.encode).join('\n'));
  } on JsonUnsupportedObjectError catch (e) {
    print([e, e.unsupportedObject, e.cause, e.stackTrace]);
    rethrow;
  }
}

MiniSum _process(String content) {
  var output = JSON.decode(content);
  var summary = new Summary.fromJson(output);

  assert(prettyJson(summary.toJson()) == prettyJson(output));

  return new MiniSum.fromSummary(summary);
}
