// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.maintenance;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;

import 'dartdoc_analyzer.dart';
import 'download_utils.dart';
import 'messages.dart';
import 'model.dart';
import 'pubspec.dart';
import 'utils.dart';

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

double getMaintenanceScore(Maintenance maintenance, {Duration age}) {
  return applyPenalties(
      1.0, _getAllSuggestion(maintenance, age: age)?.map((s) => s.penalty));
}

List<Suggestion> _getAllSuggestion(Maintenance maintenance, {Duration age}) {
  final list = <Suggestion>[];
  final ageSuggestion = getAgeSuggestion(age);
  if (ageSuggestion != null) list.add(ageSuggestion);
  if (maintenance.suggestions != null) list.addAll(maintenance.suggestions);
  return list;
}

Suggestion getAgeSuggestion(Duration age) {
  age ??= Duration.zero;

  if (age > _twoYears) {
    return new Suggestion.warning(
        SuggestionCode.packageVersionObsolete,
        'Package is too old.',
        'The package was released more than two years ago.',
        penalty: new Penalty(amount: 10000));
  }

  // adjust score to the age
  if (age > _year) {
    final ageInWeeks = age.inDays ~/ 7;
    final daysOverAYear = age.inDays - _year.inDays;
    final basisPoints = daysOverAYear * 10000 ~/ 365;
    return new Suggestion.hint(
        SuggestionCode.packageVersionOld,
        'Package is getting outdated.',
        'The package was released ${ageInWeeks} weeks ago.',
        penalty: new Penalty(fraction: min(10000, max(0, basisPoints))));
  }

  return null;
}

Future<Maintenance> detectMaintenance(
  UrlChecker urlChecker,
  String pkgDir,
  Pubspec pubspec,
  List<CodeProblem> analyzerItems,
  List<Suggestion> dartFileSuggestions,
  List<PkgDependency> unconstrainedDeps, {
  @required DartPlatform pkgPlatform,
  bool dartdocSuccessful,
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
  var strongModeDisabled = false;
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
            strongModeDisabled = value is bool && value == false;
          }
        } catch (_) {
          maintenanceSuggestions.add(new Suggestion.warning(
              SuggestionCode.analysisOptionsParseFailed,
              'Fix `$name`.',
              'We were unable to parse `$name`.',
              file: name));
        }
        break;
      }
    }
  }

  final homepageStatus = await urlChecker.checkStatus(pubspec.homepage);
  if (homepageStatus == UrlStatus.invalid ||
      homepageStatus == UrlStatus.internal) {
    maintenanceSuggestions.add(new Suggestion.warning(
      SuggestionCode.pubspecHomepageIsNotHelpful,
      'Homepage is not helpful.',
      'Update the `homepage` property: create a website about the package or use the source repository URL.',
      penalty: new Penalty(fraction: 1000),
    ));
  } else if (homepageStatus == UrlStatus.missing) {
    maintenanceSuggestions.add(new Suggestion.warning(
      SuggestionCode.pubspecHomepageDoesNotExists,
      'Homepage does not exists.',
      'We were unable to access `${pubspec.homepage}` at the time of the analysis.',
      penalty: new Penalty(fraction: 1000),
    ));
  }

  if (pubspec.documentation != null && pubspec.documentation.isNotEmpty) {
    final documentationStatus =
        await urlChecker.checkStatus(pubspec.documentation);
    if (documentationStatus == UrlStatus.internal) {
      maintenanceSuggestions.add(new Suggestion.warning(
        SuggestionCode.pubspecDocumentationIsNotHelpful,
        'Documentation URL is not helpful.',
        'Update the `documentation` property: create a website about the package or remove it.',
        penalty: new Penalty(fraction: 100),
      ));
    } else if (documentationStatus == UrlStatus.missing) {
      maintenanceSuggestions.add(new Suggestion.warning(
        SuggestionCode.pubspecDocumentationDoesNotExists,
        'Documentation URL does not exists.',
        'We were unable to access `${pubspec.documentation}` at the time of the analysis.',
        penalty: new Penalty(fraction: 500),
      ));
    }
  }

  if (!pubspec.hasDartSdkConstraint) {
    maintenanceSuggestions.add(new Suggestion.warning(
        SuggestionCode.pubspecSdkConstraintMissing,
        'Add SDK constraint in `pubspec.yaml`.',
        'For information about setting SDK constraint, please see '
        '[https://www.dartlang.org/tools/pub/pubspec#sdk-constraints](https://www.dartlang.org/tools/pub/pubspec#sdk-constraints).',
        penalty: new Penalty(fraction: 500)));
  }

  if (pubspec.shouldWarnDart2Constraint) {
    maintenanceSuggestions.add(new Suggestion.error(
        SuggestionCode.pubspecSdkConstraintDevOnly,
        'Support Dart 2 in `pubspec.yaml`.',
        'The SDK constraint in pubspec.yaml doesn\'t allow the Dart 2.0.0 release. '
        'For information about upgrading it to be Dart 2 compatible, please see '
        '[https://www.dartlang.org/dart-2#migration](https://www.dartlang.org/dart-2#migration).',
        penalty: new Penalty(fraction: 2000)));
  }

  if (dartdocSuccessful == false) {
    maintenanceSuggestions.add(getDartdocRunFailedSuggestion());
  }

  if (pkgPlatform.hasConflict) {
    maintenanceSuggestions.add(new Suggestion.error(
        SuggestionCode.platformConflictInPkg,
        'Fix platform conflicts.',
        pkgPlatform.reason,
        penalty: new Penalty(fraction: 2000)));
  }

  if (!changelogExists) {
    maintenanceSuggestions.add(new Suggestion.warning(
        SuggestionCode.changelogMissing,
        'Maintain `CHANGELOG.md`.',
        'Changelog entries help clients to follow the progress in your code.',
        penalty: new Penalty(fraction: 2000)));
  }
  if (!readmeExists) {
    maintenanceSuggestions.add(new Suggestion.warning(
        SuggestionCode.readmeMissing,
        'Maintain `README.md`.',
        'Readme should inform others about your project, what it does, and how they can use it.',
        penalty: new Penalty(fraction: 500)));
  }
  if (!exampleExists) {
    final exampleDirExists = files.any((file) => file.startsWith('example/'));
    if (exampleDirExists) {
      maintenanceSuggestions.add(new Suggestion.hint(
          SuggestionCode.exampleMissing,
          'Maintain an example.',
          'None of the files in your `example/` directory matches a known example patterns. '
          'Common file name patterns include: `main.dart`, `example.dart` or you could also use `$pkgName.dart`.',
          penalty: new Penalty(amount: 1)));
    } else {
      maintenanceSuggestions.add(new Suggestion.hint(
          SuggestionCode.exampleMissing,
          'Maintain an example.',
          'Create a short demo in the `example/` directory to show how to use this package. '
          'Common file name patterns include: `main.dart`, `example.dart` or you could also use `$pkgName.dart`.',
          penalty: new Penalty(amount: 5)));
    }
  }
  if (oldAnalysisOptions) {
    maintenanceSuggestions.add(new Suggestion.hint(
        SuggestionCode.analysisOptionsRenameRequired,
        'Use `analysis_options.yaml`.',
        'Rename old `.analysis_options` file to `analysis_options.yaml`.'));
  }
  if (analysisOptionsExists && strongModeDisabled) {
    maintenanceSuggestions.add(new Suggestion.hint(
        SuggestionCode.analysisOptionsWeakMode,
        'The option `strong-mode: false` is being deprecated.',
        'Remove `strong-mode: false` from your `analysis_options.yaml` file:\n\n'
        '```\nanalyzer:\n  strong-mode: false\n```\n'));
  }

  final version = pubspec.version;
  final isExperimentalVersion = version.major == 0;
  final isPreReleaseVersion = version.isPreRelease;

  // Pre-v1
  if (isExperimentalVersion) {
    maintenanceSuggestions.add(new Suggestion.hint(
        SuggestionCode.packageVersionPreV1,
        'Package is pre-v1 release.',
        'While there is nothing inherently wrong with versions of `0.*.*`, it '
        'usually means that the author is still experimenting with the general '
        'direction of the API.',
        penalty: new Penalty(amount: 10)));
  }

  // Not a "gold" release
  if (isPreReleaseVersion) {
    maintenanceSuggestions.add(new Suggestion.hint(
        SuggestionCode.packageVersionPreRelease,
        'Package is pre-release.',
        'Pre-release versions should be used with caution, their API may change '
        'in breaking ways.',
        penalty: new Penalty(fraction: 200)));
  }

  // Checking the length of description.
  final description = pubspec.description?.trim();
  if (description == null || description.isEmpty) {
    maintenanceSuggestions.add(new Suggestion.warning(
        SuggestionCode.pubspecDescriptionTooShort,
        'Add `description` in `pubspec.yaml`.',
        'Description is critical to giving users a quick insight into the features '
        'of the package and why it is relevant to their query. '
        'Ideal length is between 60 and 180 characters.',
        penalty: new Penalty(fraction: 500)));
  } else if (description.length < 60) {
    maintenanceSuggestions.add(new Suggestion.hint(
        SuggestionCode.pubspecDescriptionTooShort,
        'The description is too short.',
        'Add more detail about the package, what it does and what is its target use case. '
        'Try to write at least 60 characters.',
        penalty: new Penalty(amount: 20)));
  } else if (description.length > 180) {
    maintenanceSuggestions.add(new Suggestion.hint(
        SuggestionCode.pubspecDescriptionTooLong,
        'The description is too long.',
        'Search engines will display only the first part of the description. '
        'Try to keep it under 180 characters.',
        penalty: new Penalty(amount: 10)));
  }

  final errorCount = analyzerItems.where((s) => s.isError).length;
  final warningCount = analyzerItems.where((s) => s.isWarning).length;
  final hintCount = analyzerItems.where((s) => s.isInfo).length;

  final reportedFiles = new Set();
  final onePerFileSuggestions = dartFileSuggestions
      .where((s) => reportedFiles.add(s.file))
      .toList()
        ..sort();

  if (onePerFileSuggestions.length < 5) {
    maintenanceSuggestions.addAll(onePerFileSuggestions);
  } else {
    final topSuggestions = onePerFileSuggestions.take(2).toList();
    final restSuggestions = onePerFileSuggestions.skip(2).toList();
    maintenanceSuggestions.addAll(topSuggestions);

    if (restSuggestions.isNotEmpty) {
      final bulkErrorCount = restSuggestions.where((s) => s.isError).length;
      final bulkWarningCount = restSuggestions.where((s) => s.isWarning).length;
      final bulkHintCount = restSuggestions.where((s) => s.isHint).length;
      final sb = new StringBuffer();
      sb.write('Additional issues in the following files:\n\n');

      for (var s in restSuggestions) {
        final fileAnalyzerItems =
            analyzerItems.where((cp) => cp.file == s.file).toList();

        if (fileAnalyzerItems.isNotEmpty) {
          final errorCount = fileAnalyzerItems.where((cp) => cp.isError).length;
          final warningCount =
              fileAnalyzerItems.where((cp) => cp.isWarning).length;
          final hintCount = fileAnalyzerItems.where((cp) => cp.isInfo).length;
          final issueCounts =
              formatIssueCounts(errorCount, warningCount, hintCount);
          sb.writeln('- `${s.file}` ($issueCounts)');
        } else {
          sb.writeln('- `${s.file}` (${s.description})');
        }
      }

      final level = (bulkErrorCount > 0 || bulkWarningCount > 0)
          ? SuggestionLevel.warning
          : SuggestionLevel.hint;
      maintenanceSuggestions.add(
        new Suggestion(
          SuggestionCode.bulk,
          level,
          'Fix additional ${restSuggestions.length} files with analysis or formatting issues.',
          sb.toString(),
          // These are already reflected in the fitness score, but we'll also
          // penalize them here (with a much smaller amount), reflecting the need
          // of work.
          penalty: new Penalty(
              amount:
                  bulkErrorCount * 50 + bulkWarningCount * 10 + bulkHintCount),
        ),
      );
    }
  }

  if (unconstrainedDeps != null && unconstrainedDeps.isNotEmpty) {
    final count = unconstrainedDeps.length;
    final pluralized = count == 1 ? '1 dependency' : '$count dependencies';
    final names = unconstrainedDeps
        .map((pd) => pd.package)
        .map((name) => '`$name`')
        .join(', ');
    maintenanceSuggestions.add(new Suggestion.warning(
        SuggestionCode.pubspecDependenciesUnconstrained,
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
    strongModeEnabled: !strongModeDisabled,
    isExperimentalVersion: isExperimentalVersion,
    isPreReleaseVersion: isPreReleaseVersion,
    dartdocSuccessful: dartdocSuccessful,
    errorCount: errorCount,
    warningCount: warningCount,
    hintCount: hintCount,
    suggestions: maintenanceSuggestions,
  );
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
