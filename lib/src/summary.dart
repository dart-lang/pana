// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';

import 'analyzer_output.dart';
import 'platform.dart';
import 'pub_summary.dart';
import 'pubspec.dart';

class DartFileSummary {
  final String uri;
  final int size;

  /// If this file is formatted with `dartfmt`.
  ///
  /// `true` if it is.
  /// `false` if it is not.
  /// `null` if `dartfmt` failed while running.
  final bool isFormatted;
  final List<AnalyzerOutput> analyzerItems;
  final List<String> directLibs;
  final List<String> transitiveLibs;
  final PlatformInfo platform;

  DartFileSummary(
    this.uri,
    this.size,
    this.isFormatted,
    this.analyzerItems,
    this.directLibs,
    this.transitiveLibs,
    this.platform,
  );

  factory DartFileSummary.fromJson(Map<String, dynamic> json) =>
      new DartFileSummary(
        json['uri'],
        json['size'],
        json['isFormatted'],
        (json['analyzerItems'] as List)
            ?.map((Map m) => new AnalyzerOutput.fromJson(m))
            ?.toList(growable: false),
        json['directLibs'],
        json['transitiveLibs'],
        json['platform'] == null
            ? null
            : new PlatformInfo.fromJson(json['platform']),
      );

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{
      'uri': uri,
      'size': size,
      'isFormatted': isFormatted,
      'analyzerItems': analyzerItems?.map((item) => item.toJson())?.toList()
    };

    var other = {
      'directLibs': directLibs,
      'transitiveLibs': transitiveLibs,
      'platform': platform,
    };

    other.forEach((k, v) {
      if (v != null) {
        map[k] = v;
      }
    });

    return map;
  }
}

class Summary {
  final String sdkVersion;
  final Map<String, Object> flutterVersion;
  final String packageName;
  final Version packageVersion;
  final PubSummary pubSummary;
  final Map<String, DartFileSummary> dartFiles;
  final List<AnalyzerIssue> issues;

  Summary(this.sdkVersion, this.packageName, this.packageVersion,
      this.pubSummary, this.dartFiles, this.issues,
      {this.flutterVersion});

  factory Summary.fromJson(Map<String, dynamic> json) {
    var sdkVersion = json['sdkVersion'] as String;
    var packageName = json['packageName'] as String;
    var packageVersion = new Version.parse(json['packageVersion'] as String);

    var pubSummary = new PubSummary.fromJson(json['pubSummary']);
    Map filesMap = json['dartFiles'];
    Map<String, DartFileSummary> dartFiles = new SplayTreeMap.fromIterable(
        filesMap.keys,
        value: (key) => new DartFileSummary.fromJson(filesMap[key]));
    List issuesRaw = json['issues'];
    List<AnalyzerIssue> issues =
        issuesRaw?.map((Map map) => new AnalyzerIssue.fromJson(map))?.toList();

    return new Summary(
        sdkVersion, packageName, packageVersion, pubSummary, dartFiles, issues,
        flutterVersion: json['flutterVersion']);
  }

  Iterable<AnalyzerOutput> get analyzerItems sync* {
    for (DartFileSummary dfs in dartFiles.values) {
      yield* dfs.analyzerItems;
    }
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{'sdkVersion': sdkVersion};

    if (flutterVersion != null) {
      map['flutterVersion'] = flutterVersion;
    }

    map.addAll({
      'packageName': packageName,
      'packageVersion': packageVersion.toString(),
      'pubSummary': pubSummary,
      'dartFiles': dartFiles,
    });

    if (issues != null && issues.isNotEmpty) {
      map['issues'] = issues;
    }

    return map;
  }

  PlatformSummary getPlatformSummary() {
    final PlatformInfo package =
        classifyPubspec(new Pubspec(pubSummary.pubspec));
    final Map<String, PlatformInfo> libraries = new Map.fromIterable(
      dartFiles.values.where((dfs) => dfs.platform != null),
      key: (DartFileSummary dfs) => dfs.uri,
      value: (DartFileSummary dfs) => dfs.platform,
    );
    return new PlatformSummary(package, libraries);
  }
}

class AnalyzerIssue {
  final String scope;
  final String message;
  final dynamic code;

  AnalyzerIssue(this.scope, this.message, [this.code]);

  factory AnalyzerIssue.fromJson(Map<String, dynamic> json) =>
      new AnalyzerIssue(
        json['scope'],
        json['message'],
        json['code'],
      );

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{'scope': scope, 'message': message};
    if (code != null) map['code'] = code;
    return map;
  }
}

abstract class AnalyzerScopes {
  static const String pubspec = 'pubspec';
  static const String dartAnalyzer = 'dart-analyzer';
  static const String libraryScanner = 'library-scanner';
  static const String pubUpgrade = 'pub-upgrade';
  static const String dartfmt = 'dartfmt';
}
