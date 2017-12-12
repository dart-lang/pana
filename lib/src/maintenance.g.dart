// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.maintenance;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

Maintenance _$MaintenanceFromJson(Map<String, dynamic> json) => new Maintenance(
    missingChangelog: json['missingChangelog'] as bool,
    missingReadme: json['missingReadme'] as bool,
    missingAnalysisOptions: json['missingAnalysisOptions'] as bool,
    oldAnalysisOptions: json['oldAnalysisOptions'] as bool,
    strongModeEnabled: json['strongModeEnabled'] as bool,
    isExperimentalVersion: json['isExperimentalVersion'] as bool,
    isPreReleaseVersion: json['isPreReleaseVersion'] as bool,
    errorCount: json['errorCount'] as int,
    warningCount: json['warningCount'] as int,
    hintCount: json['hintCount'] as int,
    suggestions: (json['suggestions'] as List)
        ?.map((e) => e == null
            ? null
            : new Suggestion.fromJson(e as Map<String, dynamic>))
        ?.toList());

abstract class _$MaintenanceSerializerMixin {
  bool get missingChangelog;
  bool get missingReadme;
  bool get missingAnalysisOptions;
  bool get oldAnalysisOptions;
  bool get strongModeEnabled;
  bool get isExperimentalVersion;
  bool get isPreReleaseVersion;
  int get errorCount;
  int get warningCount;
  int get hintCount;
  List<Suggestion> get suggestions;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'missingChangelog': missingChangelog,
      'missingReadme': missingReadme,
      'missingAnalysisOptions': missingAnalysisOptions,
      'oldAnalysisOptions': oldAnalysisOptions,
      'strongModeEnabled': strongModeEnabled,
      'isExperimentalVersion': isExperimentalVersion,
      'isPreReleaseVersion': isPreReleaseVersion,
      'errorCount': errorCount,
      'warningCount': warningCount,
      'hintCount': hintCount,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('suggestions', suggestions);
    return val;
  }
}
