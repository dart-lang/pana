// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';

import 'analyzer_output.dart';
import 'platform.dart';
import 'pub_summary.dart';

class DartFileSummary {
  final String uri;
  final int size;
  final bool isFormatted;
  final List<AnalyzerOutput> analyzerItems;
  final List<String> directLibs;
  final List<String> transitiveLibs;
  final Platform platform;

  DartFileSummary(
    this.uri,
    this.size,
    this.isFormatted,
    this.analyzerItems,
    this.directLibs,
    this.transitiveLibs,
    this.platform,
  ) {
    assert((platform == null) == (directLibs == null));
    assert((transitiveLibs == null) || (directLibs != null));
  }

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
            : new Platform.fromJson(json['platform']),
      );

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{
      'uri': uri,
      'size': size,
      'isFormatted': isFormatted,
      'analyzerItems': analyzerItems?.map((item) => item.toJson())?.toList()
    };

    if (platform != null) {
      assert(directLibs != null);

      map.addAll({
        'platform': platform,
        'directLibs': directLibs,
      });

      if (transitiveLibs != null) {
        map['transitiveLibs'] = transitiveLibs;
      }
    }

    return map;
  }
}

class Summary {
  final String sdkVersion;
  final String flutterVersion;
  final String packageName;
  final Version packageVersion;
  final PubSummary pubSummary;
  final Map<String, DartFileSummary> dartFiles;

  Summary(this.sdkVersion, this.packageName, this.packageVersion,
      this.pubSummary, this.dartFiles,
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

    return new Summary(
        sdkVersion, packageName, packageVersion, pubSummary, dartFiles,
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

    return map;
  }
}
