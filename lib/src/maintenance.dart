// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.maintenance;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart' as yaml;

import 'summary.dart' show Suggestion;
import 'utils.dart';

part 'maintenance.g.dart';

final Duration _year = const Duration(days: 365);
final Duration _twoYears = _year * 2;

final List<String> changelogFileNames = const [
  'changelog.md',
  'changelog',
];

final List<String> readmeFileNames = const [
  'readme.md',
  'readme',
];

const String currentAnalysisOptionsFileName = 'analysis_options.yaml';
final List<String> analysisOptionsFiles = const [
  currentAnalysisOptionsFileName,
  '.analysis_options',
];

String firstFileFromNames(List<String> files, List<String> names,
    {bool caseSensitive: false}) {
  for (var name in names) {
    for (var file in files) {
      if (file == name) {
        return file;
      } else if (!caseSensitive && file.toLowerCase() == name) {
        return file;
      }
    }
  }
  return null;
}

/// Describes the maintenance status of the package.
@JsonSerializable()
class Maintenance extends Object with _$MaintenanceSerializerMixin {
  /// whether the package has no or too small changelog
  final bool missingChangelog;

  /// whether the package has no or too small readme
  final bool missingReadme;

  /// whether the package has no analysis_options.yaml file
  final bool missingAnalysisOptions;

  /// whether the package has only an old .analysis-options file
  final bool oldAnalysisOptions;

  /// whether the analysis_options.yaml file has strong mode enabled
  final bool strongModeEnabled;

  /// whether version is `0.*`
  final bool isExperimentalVersion;

  /// whether version is flagged `-beta`, `-alpha`, etc.
  final bool isPreReleaseVersion;

  /// the number of errors encountered during analysis
  final int errorCount;

  /// the number of warning encountered during analysis
  final int warningCount;

  /// the number of hints encountered during analysis
  final int hintCount;

  Maintenance({
    @required this.missingChangelog,
    @required this.missingReadme,
    @required this.missingAnalysisOptions,
    @required this.oldAnalysisOptions,
    @required this.strongModeEnabled,
    @required this.isExperimentalVersion,
    @required this.isPreReleaseVersion,
    @required this.errorCount,
    @required this.warningCount,
    @required this.hintCount,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceFromJson(json);

  List<ExplainScore> explainScore({Duration age}) {
    final explanations = <ExplainScore>[];

    if (age != null) {
      final daysLeft = (_twoYears - age).inDays;
      final p = daysLeft / 365;
      final score = max(0.0, min(1.0, p));

      if (score == 0.0) {
        explanations.add(new ExplainScore._(ExplainType.vintage, 0.0));
        return explanations;
      } else if (score < 1.0) {
        explanations.add(new ExplainScore._(ExplainType.outdated, score));
      } else {
        explanations.add(new ExplainScore._(ExplainType.vintage, 1.0));
      }
    }

    explanations.add(ExplainScore._readme(missingReadme));
    explanations.add(ExplainScore._changelog(missingChangelog));

    // Pre-v1
    if (isExperimentalVersion) {
      explanations.add(new ExplainScore._(ExplainType.experimental, 0.98));
    }

    // Not a "gold" release
    if (isPreReleaseVersion) {
      explanations.add(new ExplainScore._(ExplainType.preRelease, 0.95));
    }

    // Stable!
    if (!(isPreReleaseVersion || isExperimentalVersion)) {
      explanations.add(new ExplainScore._(ExplainType.stable, 1.00));
    }

    // Bulk penalties. A few of these overlap with the penalties above, but the
    // difference is negligible, and not worth to compensate it.
    explanations.add(new ExplainScore._(ExplainType.errors, 0.8, errorCount));
    explanations
        .add(new ExplainScore._(ExplainType.warnings, 0.99, warningCount));
    explanations.add(new ExplainScore._(ExplainType.hints, 0.999, hintCount));

    return explanations;
  }

  double getMaintenanceScore({Duration age}) => explainScore(age: age)
      .fold(1.0, (previous, score) => previous * score.scale);
}

enum ExplainType {
  /// More than 2 years since last update.
  vintage,

  /// More than 1 year since last update.
  outdated,

  /// Less than a year since the last update.
  updated,

  /// Package has a changelog.
  hasChangelog,

  /// Package is missing a changelog
  missingChangelog,

  /// Package has a readme.
  hasReadme,

  /// Package is missing a readme
  missingReadme,

  /// whether version is `0.*`
  experimental,

  /// Whether version is flagged `-beta`, `-alpha`, etc.
  preRelease,

  /// This is a stable release.
  stable,

  errors,

  warnings,

  hints,
}

final _explainTypeStrings = new Map<ExplainType, String>.fromIterable(
    ExplainType.values,
    key: (e) => e as ExplainType,
    value: (e) => e.toString().split('.').last);

class ExplainScore {
  final ExplainType explanation;
  final double simpleScale;
  final int exponent;
  final double scale;

  static ExplainScore _readme(bool missing) => missing
      ? new ExplainScore._(ExplainType.missingReadme, 0.95)
      : new ExplainScore._(ExplainType.hasReadme, 1.0);

  static ExplainScore _changelog(bool missing) => missing
      ? new ExplainScore._(ExplainType.missingChangelog, 0.8)
      : new ExplainScore._(ExplainType.hasChangelog, 1.0);

  ExplainScore._(this.explanation, this.simpleScale, [this.exponent])
      : this.scale = pow(simpleScale, exponent ?? 1) {
    assert(explanation != null);
    assert(simpleScale >= 0.0 && simpleScale <= 1.0);
    assert(exponent == null || exponent >= 0);
    assert(scale >= 0.0 && scale <= 1.0);
  }

  String toString() {
    final typeStr = _explainTypeStrings[explanation];

    final value = 'ExplainScore: $typeStr ${scale.toStringAsFixed(2)}';
    if (exponent == null) {
      return value;
    }
    return '$value ($simpleScale ^ $exponent)';
  }
}

Future<Maintenance> detectMaintenance(
    String pkgDir, Version version, List<Suggestion> suggestions) async {
  final files = await listFiles(pkgDir).toList();

  Future<bool> anyFileExists(
    List<String> names, {
    bool caseSensitive: false,
    int minLength: 0,
  }) async {
    final fileName =
        firstFileFromNames(files, names, caseSensitive: caseSensitive);
    if (fileName != null) {
      final file = new File(p.join(pkgDir, fileName));
      if (await file.exists()) {
        final length = await file.length();
        return length >= minLength;
      }
    }
    return false;
  }

  final changelogExists = await anyFileExists(changelogFileNames);
  final readmeExists = await anyFileExists(readmeFileNames);
  final analysisOptionsExists =
      await anyFileExists(analysisOptionsFiles, caseSensitive: true);
  final oldAnalysisOptions =
      analysisOptionsExists && !files.contains(currentAnalysisOptionsFileName);
  var strongModeEnabled = false;
  if (analysisOptionsExists) {
    for (var name in analysisOptionsFiles) {
      final file = new File(p.join(pkgDir, name));
      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          final Map map = yaml.loadYaml(content);
          final analyzer = map['analyzer'];
          if (analyzer != null) {
            final value = analyzer['strong-mode'];
            strongModeEnabled =
                value != null && (value == true || value is Map);
          }
        } catch (_) {
          suggestions.add(new Suggestion.warning(
              'Fix `$name`.', 'We were unable to parse `$name`.',
              file: name));
        }
        break;
      }
    }
  }

  // it is a bit crappy to update the list of suggestions here
  // TODO: make these in separate steps

  if (!changelogExists) {
    suggestions.add(new Suggestion.warning('Maintain `CHANGELOG.md`.',
        'Changelog entries help clients to follow the progress in your code.'));
  }
  if (!readmeExists) {
    suggestions.add(new Suggestion.warning('Maintain `README.md`.',
        'Readme should inform others about your project, what it does, and how they can use it.'));
  }
  if (oldAnalysisOptions) {
    suggestions.add(new Suggestion.hint('Use `analysis_options.yaml`.',
        'Rename old `.analysis_options` file to `analysis_options.yaml`.'));
  }
  if (analysisOptionsExists && !strongModeEnabled) {
    suggestions.add(new Suggestion.hint(
        'Enable strong mode analysis.',
        'Strong mode helps you to detect bugs and potential issues earlier.'
        'Start your `analysis_options.yaml` file with the following:\n\n'
        '```\nanalyzer:\n  strong-mode: true\n```\n'));
  }

  return new Maintenance(
    missingChangelog: !changelogExists,
    missingReadme: !readmeExists,
    missingAnalysisOptions: !analysisOptionsExists,
    oldAnalysisOptions: oldAnalysisOptions,
    strongModeEnabled: strongModeEnabled,
    isExperimentalVersion: version.major == 0,
    isPreReleaseVersion: version.isPreRelease,
    errorCount: suggestions.where((s) => s.isError).length,
    warningCount: suggestions.where((s) => s.isWarning).length,
    hintCount: suggestions.where((s) => s.isHint).length,
  );
}
