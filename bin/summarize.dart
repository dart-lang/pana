import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:pana/src/analyzer_output.dart';
import 'package:pana/src/summary.dart';
import 'package:path/path.dart' as p;

main() async {
  var dir = new Directory("pkg_clean.1491503303478");

  var items = dir
      .listSync()
      .where((fse) => fse is File && p.extension(fse.path) == '.json')
      .toList();

  for (File jsonFile in items) {
    _process(jsonFile.readAsStringSync());
  }
}

String _prettyString(Object o) => const JsonEncoder.withIndent(' ').convert(o);

_process(String content) {
  var output = JSON.decode(content);
  var summary = new Summary.fromJson(output);
  assert(_prettyString(summary.toJson()) == _prettyString(output));

  print(JSON.encode(new _MiniSum.fromSummary(summary)));
}

class _MiniSum {
  final String name;
  final String version;
  final int unformattedFiles;
  final Set<AnalyzerOutput> analyzerItems;
  final bool pubClean;

  _MiniSum._(this.name, this.version, this.unformattedFiles, this.analyzerItems,
      this.pubClean);

  factory _MiniSum.fromSummary(Summary summary) {
    return new _MiniSum._(
        summary.packageName,
        summary.packageVersion.toString(),
        summary.unformattedFiles.length,
        summary.analyzerItems,
        summary.pubSummary.exitCode == 0);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'version': version,
        'unformattedFiles': unformattedFiles,
        'analyzerErrors': _analyzerItemJson.length,
        'pubClean': pubClean
      };

  Iterable<Map<String, Object>> get _analyzerItemJson sync* {
    var errorTypes = new SplayTreeMap<String, int>();
    for (var a in analyzerItems) {
      if (a.type.startsWith('INFO|')) {
        continue;
      }

      var itemPath = p.split(a.file).first;
      if (const ['bin', 'lib'].contains(itemPath)) {
        errorTypes[a.type] = 1 + errorTypes.putIfAbsent(a.type, () => 0);
      }
    }

    for (var errorType in errorTypes.keys) {
      yield {'error': errorType, 'count': errorTypes[errorType]};
    }
  }
}
