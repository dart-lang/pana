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

import 'summary.dart' show applyPenalties, Penalty, Suggestion;
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

  /// The suggestions that affect the maintenance score.
  @JsonKey(includeIfNull: false)
  final List<Suggestion> suggestions;

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
    this.suggestions,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceFromJson(json);

  double getMaintenanceScore({Duration age}) =>
      applyPenalties(1.0, getAllSuggestion(age: age)?.map((s) => s.penalty));

  List<Suggestion> getAllSuggestion({Duration age}) {
    final list = <Suggestion>[];
    final ageSuggestion = getAgeSuggestion(age);
    if (ageSuggestion != null) list.add(ageSuggestion);
    if (suggestions != null) list.addAll(suggestions);
    return list;
  }

  Suggestion getAgeSuggestion(Duration age) {
    age ??= const Duration();

    if (age > _twoYears) {
      return new Suggestion.warning('Package is too old.',
          'The package was released more than two years ago.',
          penalty: new Penalty(amount: 10000));
    }

    // adjust score to the age
    if (age > _year) {
      final ageInWeeks = age.inDays ~/ 7;
      final daysOverAYear = age.inDays - _year.inDays;
      final basisPoints = daysOverAYear * 10000 ~/ 365;
      return new Suggestion.hint('Package is getting outdated.',
          'The package was released ${ageInWeeks} weeks ago.',
          penalty: new Penalty(fraction: min(10000, max(0, basisPoints))));
    }

    return null;
  }
}

Future<Maintenance> detectMaintenance(
    String pkgDir, Version version, List<Suggestion> suggestions) async {
  final maintenanceSuggestions = <Suggestion>[];
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
          maintenanceSuggestions.add(new Suggestion.warning(
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
    maintenanceSuggestions.add(new Suggestion.warning(
        'Maintain `CHANGELOG.md`.',
        'Changelog entries help clients to follow the progress in your code.',
        penalty: new Penalty(fraction: 2000)));
  }
  if (!readmeExists) {
    maintenanceSuggestions.add(new Suggestion.warning('Maintain `README.md`.',
        'Readme should inform others about your project, what it does, and how they can use it.',
        penalty: new Penalty(fraction: 500)));
  }
  if (oldAnalysisOptions) {
    maintenanceSuggestions.add(new Suggestion.hint(
        'Use `analysis_options.yaml`.',
        'Rename old `.analysis_options` file to `analysis_options.yaml`.'));
  }
  if (analysisOptionsExists && !strongModeEnabled) {
    maintenanceSuggestions.add(new Suggestion.hint(
        'Enable strong mode analysis.',
        'Strong mode helps you to detect bugs and potential issues earlier.'
        'Start your `analysis_options.yaml` file with the following:\n\n'
        '```\nanalyzer:\n  strong-mode: true\n```\n'));
  }

  final isExperimentalVersion = version.major == 0;
  final isPreReleaseVersion = version.isPreRelease;

  // Pre-v1
  if (isExperimentalVersion) {
    maintenanceSuggestions.add(new Suggestion.hint(
        'Package is pre-v1 release.',
        'While there is nothing inherently wrong with versions of `0.*.*`, it '
        'usually means that the author is still experimenting with the general '
        'direction API.',
        penalty: new Penalty(amount: 10)));
  }

  // Not a "gold" release
  if (isPreReleaseVersion) {
    maintenanceSuggestions.add(new Suggestion.hint(
        'Package is pre-release.',
        'Pre-release versions should be used with caution, their API may change '
        'in breaking ways.',
        penalty: new Penalty(fraction: 200)));
  }

  final errorCount = suggestions.where((s) => s.isError).length;
  final warningCount = suggestions.where((s) => s.isWarning).length;
  final hintCount = suggestions.where((s) => s.isHint).length;

  if (errorCount > 0 || warningCount > 0) {
    maintenanceSuggestions.add(new Suggestion.warning(
        'Fix issues reported by `dartanalyzer`.',
        '`dartanalyzer` reported $errorCount error(s) and $warningCount warning(s).',
        // 5% for each error, 1% for each warning
        penalty: new Penalty(fraction: errorCount * 500 + warningCount * 100)));
  }
  if (hintCount > 0) {
    maintenanceSuggestions.add(new Suggestion.warning(
        'Fix hints reported by `dartanalyzer`.',
        '`dartanalyzer` reported $hintCount hint(s).',
        // 0.001 for each hint
        penalty: new Penalty(amount: hintCount * 10)));
  }

  return new Maintenance(
    missingChangelog: !changelogExists,
    missingReadme: !readmeExists,
    missingAnalysisOptions: !analysisOptionsExists,
    oldAnalysisOptions: oldAnalysisOptions,
    strongModeEnabled: strongModeEnabled,
    isExperimentalVersion: isExperimentalVersion,
    isPreReleaseVersion: isPreReleaseVersion,
    errorCount: errorCount,
    warningCount: warningCount,
    hintCount: hintCount,
    suggestions: maintenanceSuggestions,
  );
}
