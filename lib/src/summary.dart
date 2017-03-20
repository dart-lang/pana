import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'analyzer_output.dart';

class Summary {
  // TODO: version
  // TODO: dartfmt
  // TODO: dart sdk version
  final String packageName;
  final PubSummary pubSummary;
  final Set<AnalyzerOutput> analyzerItems;

  Summary(this.packageName, this.pubSummary, this.analyzerItems);

  Set<String> get resultTypes =>
      new SplayTreeSet<String>.from(analyzerItems.map((ao) => ao.type));

  int issuesForType(String type) => analyzerItems
      .where((AnalyzerOutput output) => output.type == type)
      .length;

  Map<String, int> get issueSummary =>
      new Map.fromIterable(resultTypes, value: issuesForType);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'packageName': packageName,
        'pubSummary': pubSummary,
        'analyzerItems': analyzerItems.toList(growable: false)
      };
}

final _prefix = new RegExp(r"(MSG|  ) (:|\|) (?:\+| ) (.+)");
final _infoRegexp = new RegExp(r"(\w+) (\S+)(?: \((\S+) available\))?");

class PubSummary {
  final int exitCode;
  final String stdout;
  final String stderr;
  final String pubspecContent;
  final String lockFileContent;
  final Map<String, Version> packageVersions;
  final Map<String, Version> availableVersions;

  PubSummary._(this.exitCode, this.stdout, this.stderr, this.packageVersions,
      this.availableVersions, this.pubspecContent, this.lockFileContent);

  static PubSummary create(
      int exitCode, String stdout, String stderr, String path) {
    Map<String, Version> pkgVersions;
    Map<String, Version> availVersions;

    if (exitCode == 0) {
      pkgVersions = <String, Version>{};
      availVersions = <String, Version>{};

      for (var match in LineSplitter
          .split(stdout)
          .map((l) => _prefix.firstMatch(l)?.group(3))
          .where((m) => m != null)
          .map((l) => _infoRegexp.allMatches(l).single)) {
        var pkg = match.group(1);

        pkgVersions[pkg] = new Version.parse(match.group(2));

        var availVerStr = match.group(3);

        if (availVerStr != null) {
          availVersions[pkg] = new Version.parse(availVerStr);
        }
      }
    }

    String pubspecContent, lockFileContent;
    if (path != null) {
      var theFile = new File(p.join(path, 'pubspec.yaml'));
      if (theFile.existsSync()) {
        pubspecContent = theFile.readAsStringSync();
      }

      theFile = new File(p.join(path, 'pubspec.lock'));
      if (theFile.existsSync()) {
        lockFileContent = theFile.readAsStringSync();
      }
    }

    return new PubSummary._(exitCode, stdout, stderr, pkgVersions,
        availVersions, pubspecContent, lockFileContent);
  }

  Version get pkgVersion {
    if (pubspecContent == null) {
      return null;
    }

    var yaml = loadYaml(pubspecContent) as YamlMap;

    return new Version.parse(yaml['version']);
  }

  Map<String, dynamic> toJson() {
    if (exitCode == 0) {
      var map = <String, dynamic>{
        'packages': _versionMapToJson(packageVersions),
        'availablePackages': _versionMapToJson(availableVersions)
      };

      var ver = pkgVersion;
      if (ver != null) {
        map['version'] = ver.toString();
      }

      return map;
    } else {
      return <String, dynamic>{
        'exitCode': exitCode,
        'stdout': stdout,
        'stderr': stderr
      };
    }
  }

  static Map<String, dynamic> _versionMapToJson(Map<String, Version> input) =>
      new Map<String, String>.fromIterable(input.keys,
          value: (String i) => input[i].toString());
}
