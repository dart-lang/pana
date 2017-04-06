import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'analyzer_output.dart';

class Summary {
  final String sdkVersion;
  final String packageName;
  final Version packageVersion;
  final PubSummary pubSummary;
  final Set<AnalyzerOutput> analyzerItems;
  final List<String> unformattedFiles;

  Summary(this.sdkVersion, this.packageName, this.packageVersion,
      this.pubSummary, this.analyzerItems, this.unformattedFiles);

  factory Summary.fromJson(Map<String, dynamic> json) {
    var sdkVersion = json['sdkVersion'] as String;
    var packageName = json['packageName'] as String;
    var packageVersion = new Version.parse(json['packageVersion'] as String);
    var unformattedFiles = new List<String>.from(json['unformattedFiles']);

    var pubSummary = new PubSummary.fromJson(json['pubSummary']);
    var analyzerItems = (json['analyzerItems'] as List)
        .map((e) => new AnalyzerOutput.fromJson(e))
        .toSet();

    return new Summary(sdkVersion, packageName, packageVersion, pubSummary,
        analyzerItems, unformattedFiles);
  }

  Set<String> get resultTypes =>
      new SplayTreeSet<String>.from(analyzerItems.map((ao) => ao.type));

  int issuesForType(String type) => analyzerItems
      .where((AnalyzerOutput output) => output.type == type)
      .length;

  Map<String, int> get issueSummary =>
      new Map.fromIterable(resultTypes, value: issuesForType);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sdkVersion': sdkVersion,
        'packageName': packageName,
        'packageVersion': packageVersion.toString(),
        'pubSummary': pubSummary,
        'analyzerItems': analyzerItems.toList(growable: false),
        'unformattedFiles': unformattedFiles
      };
}

final _prefix = new RegExp(r"(MSG|  ) (:|\|) (?:\+| ) (.+)");
final _infoRegexp = new RegExp(r"(\w+) (\S+)(?: \((\S+) available\))?");

class PubSummary {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Version pkgVersion;
  final String lockFileContent;
  final Map<String, Version> packageVersions;
  final Map<String, Version> availableVersions;

  PubSummary._(this.exitCode, this.stdout, this.stderr, this.packageVersions,
      this.availableVersions, this.pkgVersion, this.lockFileContent);

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
          .map((l) {
        var allMatches = _infoRegexp.allMatches(l).toList();
        if (allMatches.length > 1) {
          throw "Weird! – can't parse '$l'";
        }
        return _infoRegexp.allMatches(l).single;
      })) {
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

    Version pubspecVersion;
    if (pubspecContent != null) {
      var yaml = loadYaml(pubspecContent) as YamlMap;
      pubspecVersion = new Version.parse(yaml['version']);
    }

    return new PubSummary._(exitCode, stdout, stderr, pkgVersions,
        availVersions, pubspecVersion, lockFileContent);
  }

  factory PubSummary.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('packages')) {
      var packageVersion = new Version.parse(json['version']);

      var packageVersions = _jsonMapToVersion(json['packages']);
      var availableVersions = _jsonMapToVersion(json['availablePackages']);

      return new PubSummary._(
          0, '', '', packageVersions, availableVersions, packageVersion, '');
    }

    return new PubSummary._(json['exitCode'], json['stdout'], json['stderr'],
        null, null, null, null);
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

  static Map<String, dynamic> _jsonMapToVersion(Map<String, String> input) =>
      new Map<String, Version>.fromIterable(input.keys,
          value: (String i) => new Version.parse(input[i]));
}
