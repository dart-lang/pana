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
  final Map<String, int> dartFiles;

  Summary(
      this.sdkVersion,
      this.packageName,
      this.packageVersion,
      this.dartFiles,
      this.pubSummary,
      this.analyzerItems,
      this.unformattedFiles);

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

    var dartFiles = json['dartFiles'] as Map;

    return new Summary(
        sdkVersion,
        packageName,
        packageVersion,
        new SplayTreeMap<String, int>.from(dartFiles),
        pubSummary,
        analyzerItems,
        unformattedFiles);
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
        'dartFiles': dartFiles,
        'pubSummary': pubSummary,
        'analyzerItems': analyzerItems.toList(growable: false),
        'unformattedFiles': unformattedFiles.toList(growable: false)
      };
}
