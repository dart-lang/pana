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
    isExperimentalVersion: json['isExperimentalVersion'] as bool,
    isPreReleaseVersion: json['isPreReleaseVersion'] as bool,
    toolIssueCount: json['toolIssueCount'] as int);

abstract class _$MaintenanceSerializerMixin {
  bool get missingChangelog;
  bool get missingReadme;
  bool get missingAnalysisOptions;
  bool get oldAnalysisOptions;
  bool get isExperimentalVersion;
  bool get isPreReleaseVersion;
  int get toolIssueCount;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'missingChangelog': missingChangelog,
        'missingReadme': missingReadme,
        'missingAnalysisOptions': missingAnalysisOptions,
        'oldAnalysisOptions': oldAnalysisOptions,
        'isExperimentalVersion': isExperimentalVersion,
        'isPreReleaseVersion': isPreReleaseVersion,
        'toolIssueCount': toolIssueCount
      };
}
