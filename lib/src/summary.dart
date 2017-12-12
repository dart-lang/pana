// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.summary;

import 'dart:convert';
import 'dart:math' as math;

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

import 'code_problem.dart';
import 'fitness.dart';
import 'license.dart';
import 'maintenance.dart';
import 'pkg_resolution.dart';
import 'platform.dart';
import 'pubspec.dart';
import 'sdk_info.dart';
import 'utils.dart' show toRelativePath;

part 'summary.g.dart';

@JsonSerializable()
class DartFileSummary extends Object with _$DartFileSummarySerializerMixin {
  final String uri;
  final int size;

  /// If this file is formatted with `dartfmt`.
  ///
  /// `true` if it is.
  /// `false` if it is not.
  /// `null` if `dartfmt` failed while running.
  final bool isFormatted;
  final List<CodeProblem> codeProblems;

  @JsonKey(includeIfNull: false)
  final List<String> directLibs;
  @JsonKey(includeIfNull: false)
  final List<String> transitiveLibs;
  @JsonKey(includeIfNull: false)
  final DartPlatform platform;
  @JsonKey(includeIfNull: false)
  final Fitness fitness;

  DartFileSummary(
    this.uri,
    this.size,
    this.isFormatted,
    this.codeProblems,
    this.directLibs,
    this.transitiveLibs,
    this.platform,
    this.fitness,
  );

  factory DartFileSummary.fromJson(Map<String, dynamic> json) =>
      _$DartFileSummaryFromJson(json);

  /// The relative path in the package archive.
  String get path => toRelativePath(uri);
  bool get isInBin => path.startsWith('bin/');
  bool get isInLib => path.startsWith('lib/');
  bool get isInLibSrc => path.startsWith('lib/src/');

  /// Whether the file provides a public API for the package users.
  bool get isPublicApi => isInLib && !isInLibSrc;

  /// Whether the file has any local import that point outside of the lib/
  bool get hasOutsideLibDependency =>
      directLibs != null &&
      directLibs.any((String lib) => lib.startsWith('asset:'));

  bool get hasCodeError =>
      (codeProblems?.any((cp) => cp.isError) ?? false) ||
      hasOutsideLibDependency;

  CodeProblem get firstCodeError =>
      codeProblems?.firstWhere((cp) => cp.isError, orElse: () => null);
}

@JsonSerializable()
class Summary extends Object with _$SummarySerializerMixin {
  @JsonKey(nullable: false)
  final Version panaVersion;

  @JsonKey(nullable: false)
  final Version sdkVersion;

  @JsonKey(includeIfNull: false)
  final Map<String, Object> flutterVersion;
  final String packageName;

  @JsonKey(includeIfNull: false)
  final Version packageVersion;

  final Pubspec pubspec;

  final DartPlatform platform;
  final List<LicenseFile> licenses;

  @JsonKey(includeIfNull: false)
  final Maintenance maintenance;

  final Fitness fitness;

  @JsonKey(includeIfNull: false)
  final List<Suggestion> suggestions;

  final PkgResolution pkgResolution;
  final Map<String, DartFileSummary> dartFiles;

  Summary(
      this.panaVersion,
      this.sdkVersion,
      this.packageName,
      this.packageVersion,
      this.pubspec,
      this.pkgResolution,
      this.dartFiles,
      this.platform,
      this.licenses,
      this.fitness,
      this.maintenance,
      this.suggestions,
      {this.flutterVersion});

  factory Summary.fromJson(Map<String, dynamic> json) {
    var panaVersion = new Version.parse(json['panaVersion']);
    if (panaVersion.major == 0 && panaVersion.minor < 7) {
      // Update the json in-place to have the expected values
      var info = new DartSdkInfo.parse(json['sdkVersion']);
      json['sdkVersion'] = info.version.toString();
    }

    return _$SummaryFromJson(json);
  }

  Iterable<CodeProblem> get codeProblems => dartFiles.values
      .map((dfs) => dfs.codeProblems)
      .where((l) => l != null)
      .expand((list) => list);
}

@JsonSerializable()
class Suggestion extends Object
    with _$SuggestionSerializerMixin
    implements Comparable<Suggestion> {
  final String level;
  final String title;
  final String description;

  @JsonKey(includeIfNull: false)
  final String file;

  @JsonKey(includeIfNull: false)
  final Penalty penalty;

  Suggestion(
    this.level,
    this.title,
    this.description, {
    this.file,
    this.penalty,
  });

  factory Suggestion.bug(String message, Object error, StackTrace stack) {
    final title =
        'There is likely a bug in the analysis code or a dependency: $message';
    final description =
        LineSplitter.split([error, '', stack].join('\n')).take(100).join('\n');
    return new Suggestion(SuggestionLevel.bug, title, description);
  }

  factory Suggestion.error(String title, String description,
          {String file, Penalty penalty}) =>
      new Suggestion(SuggestionLevel.error, title, description,
          file: file, penalty: penalty);

  factory Suggestion.warning(String title, String description,
          {String file, Penalty penalty}) =>
      new Suggestion(SuggestionLevel.warning, title, description,
          file: file, penalty: penalty);

  factory Suggestion.hint(String title, String description,
          {String file, Penalty penalty}) =>
      new Suggestion(SuggestionLevel.hint, title, description,
          file: file, penalty: penalty);

  factory Suggestion.fromJson(Map<String, dynamic> json) =>
      _$SuggestionFromJson(json);

  /// An issue that prevents platform classification.
  bool get isError =>
      level == SuggestionLevel.error || level == SuggestionLevel.bug;

  /// An issue that would improve the package quality if fixed.
  bool get isWarning => level == SuggestionLevel.warning;

  /// An issue that would be nice if it were fixed.
  bool get isHint => level == SuggestionLevel.hint;

  @override
  int compareTo(Suggestion other) {
    if (isError && !other.isError) return -1;
    if (other.isError && !isError) return 1;
    if (isWarning && !other.isError && !other.isWarning) return -1;
    if (other.isWarning && !isError && !isWarning) return 1;
    return 0;
  }

  String toString() => 'Sugestion: $level - $description';
}

abstract class SuggestionLevel {
  static const String error = 'error';
  static const String warning = 'warning';
  static const String hint = 'hint';
  static const String bug = 'bug';
}

/// Penalty values are set as integers, and shall be divided by 10000 for any
/// numerical calculation (similar to basis points in finance).
///
/// When multiple operations are present, the larger penalty is applied.
@JsonSerializable()
class Penalty extends Object with _$PenaltySerializerMixin {
  /// The value to subtract from the original score.
  /// E.g. if [amount] is 123, this is `x = x - 0.0123;`
  @JsonKey(includeIfNull: false)
  final int amount;

  /// The fraction to substract from the original score.
  /// E.g. if [fraction is 123, this is `x = x * (1.0 - 0.0123);`
  @JsonKey(includeIfNull: false)
  final int fraction;

  Penalty({
    this.amount: 0,
    this.fraction: 0,
  }) {
    assert(amount > 0 || fraction > 0);
    assert(0 <= amount && amount <= 10000);
    assert(0 <= fraction && fraction <= 10000);
  }

  factory Penalty.fromJson(Map<String, dynamic> json) =>
      _$PenaltyFromJson(json);

  double apply(double score) {
    final d1 = amount / 10000;
    final d2 = score * fraction / 10000;
    final s = score - math.max(d1, d2);
    return math.max(0.0, s);
  }
}

double applyPenalties(double initialScore, Iterable<Penalty> penalties) {
  if (penalties == null) return initialScore;
  var score = initialScore;
  for (var p in penalties) {
    if (p == null) continue;
    score = p.apply(score);
  }
  return score;
}
