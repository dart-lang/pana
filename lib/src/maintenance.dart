// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.maintenance;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:json_annotation/json_annotation.dart';
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

  /// whether version is 0.0.*
  final bool isExperimentalVersion;

  /// whether version is 0.*.*
  final bool isPreReleaseVersion;

  /// the number of errors encountered during analysis
  final int errorCount;

  /// the number of warning encountered during analysis
  final int warningCount;

  /// the number of hints encountered during analysis
  final int hintCount;

  Maintenance({
    this.missingChangelog: false,
    this.missingReadme: false,
    this.missingAnalysisOptions: false,
    this.oldAnalysisOptions: false,
    this.strongModeEnabled: false,
    this.isExperimentalVersion: false,
    this.isPreReleaseVersion: false,
    this.errorCount: 0,
    this.warningCount: 0,
    this.hintCount: 0,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceFromJson(json);

  double getMaintenanceScore(DateTime publishDate) {
    final now = new DateTime.now().toUtc();
    final age = now.difference(publishDate);

    if (age > _twoYears) {
      return 0.0;
    }

    var score = 1.0;

    // adjust score to the age
    if (age > _year) {
      final daysLeft = (_twoYears - age).inDays;
      final p = daysLeft / 365;
      score *= max(0.0, min(1.0, p));
    }

    // missing files
    if (missingChangelog) score *= 0.80;
    if (missingReadme) score *= 0.95;

    // lack of confidence
    if (isExperimentalVersion) {
      score *= 0.95;
    } else if (isPreReleaseVersion) {
      score *= 0.99;
    }

    // Bulk penalties. A few of these overlap with the penalties above, but the
    // difference is negligible, and not worth to compensate it.
    score *= pow(0.80, errorCount);
    score *= pow(0.99, warningCount);
    score *= pow(0.999, hintCount);

    return score;
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

  final isPreReleaseVersion = version.major == 0;
  final isExperimentalVersion = isPreReleaseVersion && version.minor == 0;

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
    isExperimentalVersion: isExperimentalVersion,
    isPreReleaseVersion: isPreReleaseVersion,
    errorCount: suggestions.where((s) => s.isError).length,
    warningCount: suggestions.where((s) => s.isWarning).length,
    hintCount: suggestions.where((s) => s.isHint).length,
  );
}
