import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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

String prettyJson(obj) =>
    const JsonEncoder.withIndent('  ').convert(obj).trim();

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

Map<String, Object> yamlToJson(String pubspecContent) {
  if (pubspecContent == null) {
    return null;
  }
  var yamlMap = loadYaml(pubspecContent) as YamlMap;

  // A bit paranoid, but I want to make sure this is valid JSON before we got to
  // the encode phase.
  return sortedJson(JSON.decode(JSON.encode(yamlMap)));
}
