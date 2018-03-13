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
import 'package:yaml/yaml.dart' as yaml;

import 'pkg_resolution.dart';
import 'pubspec.dart';
import 'summary.dart' show Penalty, Suggestion, SuggestionLevel, applyPenalties;
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

/// Returns the candidates in priority order to display under the 'Example' tab.
List<String> exampleFileCandidates(String package) => [
      'example/lib/main.dart',
      'example/main.dart',
      'example/lib/$package.dart',
      'example/$package.dart',
      'example/lib/${package}_example.dart',
      'example/${package}_example.dart',
      'example/lib/example.dart',
      'example/example.dart',
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

  /// whether the package has no example
  final bool missingExample;

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
    @required this.missingExample,
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
  String pkgDir,
  Pubspec pubspec,
  List<Suggestion> dartFileSuggestions,
  List<PkgDependency> unconstrainedDeps, {
  @required bool hasPlatformConflict,
}) async {
  final pkgName = pubspec.name;
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
  final exampleExists = await anyFileExists(exampleFileCandidates(pkgName));
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

  if (hasPlatformConflict) {
    maintenanceSuggestions.add(new Suggestion.error('Fix platform conflicts.',
        'Make sure none of the libraries use mutually exclusive dependendencies.',
        penalty: new Penalty(fraction: 2000)));
  }

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
  if (!exampleExists) {
    final exampleDirExists = files.any((file) => file.startsWith('example/'));
    if (exampleDirExists) {
      maintenanceSuggestions.add(new Suggestion.hint(
          'Maintain an example.',
          'None of the files in your `example/` directory matches a known example patterns. '
          'Common file name patterns include: `main.dart`, `example.dart` or you could also use `$pkgName.dart`.',
          penalty: new Penalty(amount: 1)));
    } else {
      maintenanceSuggestions.add(new Suggestion.hint(
          'Maintain an example.',
          'Create a short demo in the `example/` directory to show how to use this package. '
          'Common file name patterns include: `main.dart`, `example.dart` or you could also use `$pkgName.dart`.',
          penalty: new Penalty(amount: 5)));
    }
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

  final version = pubspec.version;
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

  // Checking the length of description.
  final description = pubspec.description?.trim();
  if (description == null || description.isEmpty) {
    maintenanceSuggestions.add(new Suggestion.warning(
        'Add `description` in `pubspec.yaml`.',
        'Description is critical to giving users a quick insight into the features '
        'of the package and why it is relevant to their query. '
        'Ideal length is between 60 and 180 characters.',
        penalty: new Penalty(fraction: 500)));
  } else if (description.length < 60) {
    maintenanceSuggestions.add(new Suggestion.hint(
        'The description is too short.',
        'Add more detail about the package, what it does and what is its target use case. '
        'Try to write at least 60 characters.',
        penalty: new Penalty(amount: 20)));
  } else if (description.length > 180) {
    maintenanceSuggestions.add(new Suggestion.hint(
        'The description is too long.',
        'Search engines will display only the first part of the description. '
        'Try to keep it under 180 characters.',
        penalty: new Penalty(amount: 10)));
  }

  final errorCount = dartFileSuggestions.where((s) => s.isError).length;
  final warningCount = dartFileSuggestions.where((s) => s.isWarning).length;
  final hintCount = dartFileSuggestions.where((s) => s.isHint).length;

  if (dartFileSuggestions.isNotEmpty) {
    final sb = new StringBuffer();
    sb.write('Analysis or formatting checks reported');
    void reportIssues(int count, String name) {
      if (count == 1) {
        sb.write(' $count $name');
      } else if (count > 1) {
        sb.write(' $count ${name}s');
      }
    }

    reportIssues(errorCount, 'error');
    reportIssues(warningCount, 'warning');
    reportIssues(hintCount, 'hint');
    sb.write('.\n\n');

    final reportedFiles = new Set();
    final onePerFileSuggestions =
        dartFileSuggestions.where((s) => reportedFiles.add(s.file)).toList();
    final topSuggestions = onePerFileSuggestions.take(2).toList();
    final restSuggestions = onePerFileSuggestions.skip(2).toList();

    for (var suggestion in topSuggestions) {
      sb.write('${suggestion.description.trim()}\n\n');
    }
    if (restSuggestions.isNotEmpty) {
      sb.write('Similar analysis of the following files failed:\n\n');
      final items =
          restSuggestions.map((s) => '- `${s.file}` (${s.level})\n').join();
      sb.write(items);
    }

    final level = (errorCount > 0 || warningCount > 0)
        ? SuggestionLevel.warning
        : SuggestionLevel.hint;
    maintenanceSuggestions.add(
      new Suggestion(
        level,
        'Fix analysis and formatting issues.',
        sb.toString(),
        // These are already reflected in the fitness score, but we'll also
        // penalize them here (with a much smaller amount), reflecting the need
        // of work.
        penalty: new Penalty(
            amount: errorCount * 50 + warningCount * 10 + hintCount),
      ),
    );
  }

  if (unconstrainedDeps != null && unconstrainedDeps.isNotEmpty) {
    final count = unconstrainedDeps.length;
    final pluralized = count == 1 ? '1 dependency' : '$count dependencies';
    final names = unconstrainedDeps
        .map((pd) => pd.package)
        .map((name) => '`$name`')
        .join(', ');
    maintenanceSuggestions.add(new Suggestion.warning(
        'Use constrained dependencies.',
        'The `pubspec.yaml` contains $pluralized without version constraints. '
        'Specify version ranges for the following dependencies: $names.',
        penalty: new Penalty(fraction: 500)));
  }

  maintenanceSuggestions.sort();
  return new Maintenance(
    missingChangelog: !changelogExists,
    missingReadme: !readmeExists,
    missingExample: !exampleExists,
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
