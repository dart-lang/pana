import 'dart:collection';
import 'package:pana/src/summary.dart';

import 'package:pana/src/analyzer_output.dart';

class MiniSum {
  static const _importantDirs = const ['bin', 'lib', 'test'];

  final Summary _summary;

  bool get pubClean => _summary.pubSummary.exitCode == 0;

  Set<String> get authorDomains => new SplayTreeSet<String>.from(
      _summary.pubSummary.authors.map(_domainFromAuthor));

  int get unformattedFiles =>
      _summary.dartFiles.values.where((f) => !f.isFormatted).length;

  Set<AnalyzerOutput> get analyzerItems => _summary.analyzerItems;

  MiniSum._(this._summary);

  factory MiniSum.fromSummary(Summary summary) {
    return new MiniSum._(summary);
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
    map.addAll(_classifyFiles(_summary.dartFiles.keys));

    // format
    map['pctFormatted'] = _summary.dartFiles.isEmpty
        ? 1.0
        : 1.0 - unformattedFiles / _summary.dartFiles.length;

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
  var items = <String, int>{
    'analyzer_strong_error': 0,
    'analyzer_error': 0,
    'analyzer_topLevelStrong': 0,
    'analyzer_other': 0
  };

  for (var item in analyzerThings) {
    var fileClazz = _classifyFile(item.file);

    if (fileClazz == 'lib' || fileClazz == 'bin') {
      var key = _getAnalyzerOutputClass(item.type);
      items[key] += 1;
    }
  }

  return items;
}

String _getAnalyzerOutputClass(String type) {
  if (type.startsWith('ERROR|')) {
    if (type.contains("|STRONG_MODE_")) {
      return 'analyzer_strong_error';
    }
    return 'analyzer_error';
  }
  if (type.contains("INFO|HINT|STRONG_MODE_TOP_LEVEL_")) {
    //TODO(kevmoo) The story is changing here in Dart 1.25+
    // https://github.com/dart-lang/pana/issues/16
    return 'analyzer_topLevelStrong';
  }

  return 'analyzer_other';
}

Map<String, int> _classifyFiles(Iterable<String> paths) {
  var map = new SplayTreeMap<String, int>.fromIterable(
      (["other"]..addAll(MiniSum._importantDirs)).map((e) => "files_${e}"),
      value: (_) => 0);

  for (var path in paths) {
    var key = 'files_${_classifyFile(path)}';
    map[key] = 1 + map.putIfAbsent(key, () => 0);
  }

  return map;
}

String _classifyFile(String path) {
  var split = path.split('/');

  if (split.length >= 2 && MiniSum._importantDirs.contains(split.first)) {
    return split.first;
  }

  return 'other';
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
