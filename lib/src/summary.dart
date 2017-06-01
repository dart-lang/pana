import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';

import 'analyzer_output.dart';
import 'pub_summary.dart';

class Summary {
  final String sdkVersion;
  final String packageName;
  final Version packageVersion;
  final PubSummary pubSummary;
  final Set<AnalyzerOutput> analyzerItems;
  final Set<String> unformattedFiles;
  final Set<String> dartFiles;
  final Map<String, List<String>> directLibs;
  final Map<String, List<String>> transitiveLibs;

  Summary(
    this.sdkVersion,
    this.packageName,
    this.packageVersion,
    this.dartFiles,
    this.pubSummary,
    this.analyzerItems,
    this.unformattedFiles,
    this.directLibs,
    this.transitiveLibs,
  );

  factory Summary.fromJson(Map<String, dynamic> json) {
    var sdkVersion = json['sdkVersion'] as String;
    var packageName = json['packageName'] as String;
    var packageVersion = new Version.parse(json['packageVersion'] as String);
    var unformattedFiles =
        new SplayTreeSet<String>.from(json['unformattedFiles']);

    var pubSummary = new PubSummary.fromJson(json['pubSummary']);
    var analyzerItems = (json['analyzerItems'] as List)
        .map((e) => new AnalyzerOutput.fromJson(e))
        .toSet();

    var dartFiles = json['dartFiles'] as List<String>;
    var directLibs = json['directLibs'] as Map<String, List<String>>;
    var transitiveLibs = json['transitiveLibs'] as Map<String, List<String>>;

    return new Summary(
      sdkVersion,
      packageName,
      packageVersion,
      new SplayTreeSet<String>.from(dartFiles),
      pubSummary,
      analyzerItems,
      unformattedFiles,
      directLibs,
      transitiveLibs,
    );
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
        'dartFiles': dartFiles.toList(growable: false),
        'pubSummary': pubSummary,
        'analyzerItems': analyzerItems.toList(growable: false),
        'unformattedFiles': unformattedFiles.toList(growable: false),
        'directLibs': directLibs,
        'transitiveLibs': transitiveLibs,
      };
}
