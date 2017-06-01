// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:pana/src/analyzer_output.dart';
import 'package:pana/src/summary.dart';
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

void _updateResults(List<_MiniSum> summaries) {
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

String _prettyString(Object o) {
  try {
    return const JsonEncoder.withIndent(' ').convert(o);
  } on JsonUnsupportedObjectError catch (e) {
    print([
      e,
      e.cause,
      e.unsupportedObject,
      e.unsupportedObject.runtimeType,
      e.stackTrace
    ].join('\n'));
    rethrow;
  }
}

_MiniSum _process(String content) {
  var output = JSON.decode(content);
  var summary = new Summary.fromJson(output);

  assert(_prettyString(summary.toJson()) == _prettyString(output));

  return new _MiniSum.fromSummary(summary);
}

class _MiniSum {
  static const _importantDirs = const ['bin', 'lib', 'test'];

  final Summary _summary;

  bool get pubClean => _summary.pubSummary.exitCode == 0;

  Set<String> get authorDomains => new SplayTreeSet<String>.from(
      _summary.pubSummary.authors.map(_domainFromAuthor));

  int get unformattedFiles => _summary.unformattedFiles.length;

  Set<AnalyzerOutput> get analyzerItems => _summary.analyzerItems;

  _MiniSum._(this._summary);

  factory _MiniSum.fromSummary(Summary summary) {
    return new _MiniSum._(summary);
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{
      'name': _summary.packageName,
      'version': _summary.packageVersion.toString(),
    };

    // dependency info
    map.addAll(_summary.pubSummary.getStats());

    // analyzer info
    map.addAll(_analyzerThings(_summary.analyzerItems));

    // file info
    map.addAll(_classifyFiles(_summary.dartFiles));

    // format
    map['pctFormatted'] = _summary.dartFiles.isEmpty
        ? 1.0
        : 1.0 - _summary.unformattedFiles.length / _summary.dartFiles.length;

    map['authorDomains'] = authorDomains.join(', ');

    return map;
  }

  String getSchema() {
    var items = <String>[];

    toJson().forEach((k, v) {
      String type;

      if (v is String) {
        type = 'STRING';
      } else if (v is int) {
        type = 'INTEGER';
      } else if (v is double) {
        type = 'FLOAT';
      } else {
        throw 'Not supported! - $v - ${v.runtimeType}';
      }

      items.add("$k:$type");
    });

    return items.join(',');
  }
}

Map<String, int> _analyzerThings(Iterable<AnalyzerOutput> analyzerThings) {
  var items = <String, int>{'analyzerError': 0, 'analyzerStrong': 0};

  for (var item in analyzerThings) {
    var fileClazz = _classifyFile(item.file);

    if (fileClazz == 'libFiles' || fileClazz == 'binFiles') {
      var type = item.type;

      if (type.startsWith('ERROR|')) {
        items['analyzerError'] += 1;
      } else if (type.contains("|STRONG_MODE_")) {
        items['analyzerStrong'] += 1;
      }
    }
  }

  return items;
}

Map<String, int> _classifyFiles(Iterable<String> paths) {
  var map = new SplayTreeMap<String, int>.fromIterable(
      (["unspecified"]..addAll(_MiniSum._importantDirs))
          .map((e) => "${e}Files"),
      value: (_) => 0);

  for (var path in paths) {
    var key = _classifyFile(path);
    map[key] = 1 + map.putIfAbsent(key, () => 0);
  }

  return map;
}

String _classifyFile(String path) {
  var split = path.split('/');

  if (split.length >= 2 && _MiniSum._importantDirs.contains(split.first)) {
    return "${split.first}Files";
  }

  return 'unspecifiedFiles';
}

const _domainRegep =
    r"(?:[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}";
final _domainThing = new RegExp("[@/]($_domainRegep)>");

String _domainFromAuthor(String author) {
  var match = _domainThing.firstMatch(author);
  if (match == null) {
    return 'unknown';
  }
  return match.group(1);
}
