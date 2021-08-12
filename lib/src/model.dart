// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

import 'json_converters.dart';
import 'pubspec.dart';

part 'model.g.dart';

@JsonSerializable(includeIfNull: false)
@VersionConverter()
class Summary {
  final PanaRuntimeInfo runtimeInfo;
  final String? packageName;
  final Version? packageVersion;
  final Pubspec? pubspec;
  final LicenseFile? licenseFile;

  /// The packages that are either direct-, dev- or transient dependencies.
  final List<String>? allDependencies;
  final List<String>? tags;
  final Report? report;

  /// URLs that are invalid, unsafe or missing.
  final List<UrlProblem>? urlProblems;

  /// Markdown-formatted text with errors encountered by `pana`.
  final String? errorMessage;

  Summary({
    required this.runtimeInfo,
    this.packageName,
    this.packageVersion,
    this.pubspec,
    this.allDependencies,
    this.licenseFile,
    this.tags,
    this.report,
    this.urlProblems,
    this.errorMessage,
  });

  factory Summary.fromJson(Map<String, dynamic> json) =>
      _$SummaryFromJson(json);

  Map<String, dynamic> toJson() => _$SummaryToJson(this);

  Summary change({
    PanaRuntimeInfo? runtimeInfo,
    List<String>? tags,
  }) {
    return Summary(
      runtimeInfo: runtimeInfo ?? this.runtimeInfo,
      packageName: packageName,
      packageVersion: packageVersion,
      pubspec: pubspec,
      allDependencies: allDependencies,
      licenseFile: licenseFile,
      tags: tags ?? this.tags,
      report: report,
      urlProblems: urlProblems,
      errorMessage: errorMessage,
    );
  }
}

@JsonSerializable()
class PanaRuntimeInfo {
  final String panaVersion;
  final String sdkVersion;
  @JsonKey(includeIfNull: false)
  final Map<String, dynamic>? flutterVersions;

  PanaRuntimeInfo({
    required this.panaVersion,
    required this.sdkVersion,
    this.flutterVersions,
  });

  factory PanaRuntimeInfo.fromJson(Map<String, dynamic> json) =>
      _$PanaRuntimeInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PanaRuntimeInfoToJson(this);

  bool get hasFlutter => flutterVersions?.isNotEmpty ?? false;

  /// The Flutter SDK version.
  String? get flutterVersion => flutterVersions?['frameworkVersion'] as String?;

  /// The Dart SDK used by Flutter internally.
  String? get flutterInternalDartSdkVersion {
    final value = flutterVersions?['dartSdkVersion'] as String?;
    if (value == null) return null;
    final parts = value.split(' ');
    if (parts.length > 2 && parts[1] == '(build' && parts[2].endsWith(')')) {
      final buildValue = parts[2].split(')').first;
      try {
        Version.parse(buildValue);
        return buildValue;
      } catch (_) {
        // ignore
      }
    }
    return parts.first;
  }
}

@JsonSerializable(includeIfNull: false)
class LicenseFile {
  final String path;
  final String name;
  final String? version;
  final String? url;

  LicenseFile(this.path, this.name, {this.version, this.url});

  factory LicenseFile.fromJson(Map<String, dynamic> json) =>
      _$LicenseFileFromJson(json);

  Map<String, dynamic> toJson() => _$LicenseFileToJson(this);

  LicenseFile change({String? url}) =>
      LicenseFile(path, name, version: version, url: url ?? this.url);

  String get shortFormatted => version == null ? name : '$name $version';

  @override
  String toString() => '$path: $shortFormatted';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseFile &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          name == other.name &&
          version == other.version &&
          url == other.url;

  @override
  int get hashCode =>
      path.hashCode ^ name.hashCode ^ version.hashCode ^ url.hashCode;
}

abstract class LicenseNames {
  static const String agpl = 'AGPL';
  static const String apache = 'Apache';
  static const String bsd = 'BSD';
  static const String gpl = 'GPL';
  static const String lgpl = 'LGPL';
  static const String mit = 'MIT';
  static const String mpl = 'MPL';
  static const String unlicense = 'Unlicense';
  static const String unknown = 'unknown';
}

/// Models the 'new-style' pana report.
@JsonSerializable(explicitToJson: true)
class Report {
  /// The scoring sections.
  final List<ReportSection> sections;

  Report({required this.sections});

  static Report fromJson(Map<String, dynamic> json) => _$ReportFromJson(json);

  Map<String, dynamic> toJson() => _$ReportToJson(this);

  int get grantedPoints =>
      sections.fold<int>(0, (sum, section) => sum + section.grantedPoints);

  int get maxPoints =>
      sections.fold<int>(0, (sum, section) => sum + section.maxPoints);

  /// Creates a new [Report] instance with [section] extending and already
  /// existing [ReportSection]. The sections are matched via the `title`.
  ///
  /// The granted and max points will be added to the existing section.
  /// The status will be min of the two statuses.
  ///
  /// The summary will be appended to the end of the existing summary.
  ///
  ///
  /// If there is no section matched, the section will be added to the end of
  /// the sections list.
  Report joinSection(ReportSection section) {
    final matched = sections.firstWhereOrNull(
        (s) => (s.id == section.id) || s.title == section.title);
    if (matched == null) {
      return Report(sections: [...sections, section]);
    } else {
      return Report(
          sections: sections.map(
        (s) {
          if (s != matched) {
            return s;
          }
          return ReportSection(
              id: s.id,
              title: s.title,
              maxPoints: s.maxPoints + section.maxPoints,
              grantedPoints: s.grantedPoints + section.grantedPoints,
              summary: [s.summary.trim(), section.summary.trim()].join('\n\n'),
              status: minStatus(s.status, section.status)!);
        },
      ).toList());
    }
  }
}

abstract class ReportSectionId {
  static const analysis = 'analysis';
  static const convention = 'convention';
  static const dependency = 'dependency';
  static const documentation = 'documentation';
  static const platform = 'platform';
  static const nullSafety = 'null-safety';
}

enum ReportStatus {
  @JsonValue('failed')
  failed,
  @JsonValue('partial')
  partial,
  @JsonValue('passed')
  passed,
}

/// Returns the lowest of [statuses] to represent them.
ReportStatus summarizeStatuses(Iterable<ReportStatus> statuses) {
  return statuses.fold(ReportStatus.passed, (a, b) => minStatus(a, b)!);
}

/// Returns the lowest status of [a] and [b] ranked in the order of the enum.
///
/// Example: `minStatus(ReportStatus.failed, ReportStatus.partial) == ReportStatus.partial`.
///
/// Returns `null` when any of them is `null` (may be the case with old data).
ReportStatus? minStatus(ReportStatus? a, ReportStatus? b) {
  if (a == null || b == null) return null;
  return ReportStatus.values[min(a.index, b.index)];
}

@JsonSerializable()
class ReportSection {
  final String id;
  final String title;

  /// How many points did this section score
  final int grantedPoints;

  /// How many points could this section have scored.
  final int maxPoints;

  /// Is this section considered passing.
  final ReportStatus status;

  /// Should describe the overall goals in a few lines, followed by
  /// descriptions of each issue that resulted in [grantedPoints] being less
  /// than  [maxPoints] (if any).
  ///
  /// Markdown formatted.
  final String summary;

  ReportSection({
    required this.id,
    required this.title,
    required this.grantedPoints,
    required this.maxPoints,
    required this.summary,
    required this.status,
  });

  static ReportSection fromJson(Map<String, dynamic> json) =>
      _$ReportSectionFromJson(json);

  Map<String, dynamic> toJson() => _$ReportSectionToJson(this);
}

@JsonSerializable()
class UrlProblem {
  final String url;

  /// One of [UrlProblemCodes].
  final String problem;

  UrlProblem({
    required this.url,
    required this.problem,
  });

  factory UrlProblem.fromJson(Map<String, dynamic> json) =>
      _$UrlProblemFromJson(json);

  Map<String, dynamic> toJson() => _$UrlProblemToJson(this);
}

/// Possible values for [UrlProblem.problem].
abstract class UrlProblemCodes {
  static const invalid = 'invalid';
  static const internal = 'internal';
  static const insecure = 'insecure';
  static const missing = 'missing';
}
