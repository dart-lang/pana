// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.maintenance;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart' as pubspek;
import 'package:yaml/yaml.dart' as yaml;

import 'dartdoc_analyzer.dart';
import 'download_utils.dart';
import 'model.dart';
import 'package_analyzer.dart' show InspectOptions;
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

@deprecated
final List<String> exampleReadmeFileNames = const [
  'example/readme.md',
  'example/readme',
  'example/example.md',
  'example/example',
];

/// Returns the candidates in priority order to display under the 'Example' tab.
List<String> exampleFileCandidates(String package) {
  return <String>[
    'example/readme.md',
    'example/readme',
    'example/example.md',
    'example/example',
    'example/lib/main.dart',
    'example/main.dart',
    'example/lib/$package.dart',
    'example/$package.dart',
    'example/lib/${package}_example.dart',
    'example/${package}_example.dart',
    'example/lib/example.dart',
    'example/example.dart',
  ];
}

const String currentAnalysisOptionsFileName = 'analysis_options.yaml';
final List<String> analysisOptionsFiles = const [
  currentAnalysisOptionsFileName,
  '.analysis_options',
];

String firstFileFromNames(List<String> files, List<String> names,
    {bool caseSensitive = false}) {
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

/// Calculates the maintenance score in the range of [0.0 - 100.0].
@deprecated
double getMaintenanceScore(Maintenance maintenance, {Duration age}) {
  return _getMaintenanceScore(maintenance, age);
}

/// Calculates the maintenance score in the range of [0.0 - 1.0].
double calculateMaintenanceScore(Maintenance maintenance, {Duration age}) {
  return _getMaintenanceScore(maintenance, age) / 100.0;
}

double _getMaintenanceScore(Maintenance maintenance, Duration age) {
  var score = 100.0;
  maintenance?.suggestions
      ?.map((s) => s.score)
      ?.where((d) => d != null)
      ?.forEach((d) {
    score -= d;
  });
  final ageSuggestion = getAgeSuggestion(age);
  if (ageSuggestion?.score != null) {
    score -= ageSuggestion.score;
  }

  return max(0.0, min(100.0, score));
}

Suggestion getAgeSuggestion(Duration age) {
  age ??= Duration.zero;

  if (age > _twoYears) {
    return Suggestion.warning(
        SuggestionCode.packageVersionObsolete,
        'Package is too old.',
        'The package was released more than two years ago.',
        score: 100.0);
  }

  // adjust score to the age
  if (age > _year) {
    final ageInWeeks = age.inDays ~/ 7;
    final daysOverAYear = age.inDays - _year.inDays;
    final score = max(0.0, min(100.0, daysOverAYear * 100.0 / 365));
    return Suggestion.hint(
        SuggestionCode.packageVersionOld,
        'Package is getting outdated.',
        'The package was released $ageInWeeks weeks ago.',
        score: score);
  }

  return null;
}

/// Returns a suggestion for pubspec.yaml parse error.
Suggestion pubspecParseError(error) {
  return Suggestion.error(
    SuggestionCode.pubspecParseError,
    'Error while parsing `pubspec.yaml`.',
    'Parsing throw an exception:\n\n```\n$error\n```.',
    score: 100.0,
  );
}

/// Creates [Maintenance] with suggestions.
///
/// NOTE: In case this changes, update README.md
/// TODO: refactor method, for easier matching with documentation.
Future<Maintenance> detectMaintenance(
  InspectOptions options,
  UrlChecker urlChecker,
  String pkgDir,
  Pubspec pubspec,
  List<PkgDependency> unconstrainedDeps, {
  @required DartPlatform pkgPlatform,
  bool dartdocSuccessful,
}) async {
  final pkgName = pubspec.name;
  final maintenanceSuggestions = <Suggestion>[];
  final files = await listFiles(pkgDir).toList();

  Future<bool> anyFileExists(
    List<String> names, {
    bool caseSensitive = false,
    int minLength = 0,
  }) async {
    final fileName =
        firstFileFromNames(files, names, caseSensitive: caseSensitive);
    if (fileName != null) {
      final file = File(p.join(pkgDir, fileName));
      if (await file.exists()) {
        final length = await file.length();
        return length >= minLength;
      }
    }
    return false;
  }

  final changelogExists = await anyFileExists(changelogFileNames);
  final readmeExists = await anyFileExists(readmeFileNames);
  final exampleFileExists = await anyFileExists(exampleFileCandidates(pkgName));
  final analysisOptionsExists =
      await anyFileExists(analysisOptionsFiles, caseSensitive: true);
  final oldAnalysisOptions =
      analysisOptionsExists && !files.contains(currentAnalysisOptionsFileName);
  var strongModeDisabled = false;
  if (analysisOptionsExists) {
    for (var name in analysisOptionsFiles) {
      final file = File(p.join(pkgDir, name));
      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          final map = yaml.loadYaml(content) as Map;
          final analyzer = map['analyzer'];
          if (analyzer != null) {
            final value = analyzer['strong-mode'];
            strongModeDisabled = value is bool && value == false;
          }
        } catch (_) {
          maintenanceSuggestions.add(Suggestion.warning(
              SuggestionCode.analysisOptionsParseFailed,
              'Fix `$name`.',
              'We were unable to parse `$name`.',
              file: name));
        }
        break;
      }
    }
  }

  Future processUrlStatus(
    String key,
    String name,
    String url, {
    @required String invalidCode,
    @required String invalidAction,
    @required String http404Code,
    @required String insecureCode,
    double invalidPenalty = 10.0,
    double http404Penalty = 10.0,
    double insecurePenalty = 5.0,
  }) async {
    final status = await urlChecker.checkStatus(url,
        isInternalPackage: options.isInternal);
    if (status == UrlStatus.invalid || status == UrlStatus.internal) {
      maintenanceSuggestions.add(Suggestion.warning(
        invalidCode,
        '$name is not helpful.',
        'Update the `$key` property: $invalidAction',
        score: invalidPenalty,
      ));
    } else if (status == UrlStatus.missing) {
      maintenanceSuggestions.add(Suggestion.warning(
        http404Code,
        '$name does not exists.',
        'We were unable to access `$url` at the time of the analysis.',
        score: http404Penalty,
      ));
    } else if (status == UrlStatus.exists && !url.startsWith('https://')) {
      maintenanceSuggestions.add(Suggestion.hint(
        insecureCode,
        '$name is insecure.',
        'Update the `$key` property and use a secure (`https`) URL.',
        score: insecurePenalty,
      ));
    }
  }

  await processUrlStatus(
    'homepage',
    'Homepage URL',
    pubspec.homepage,
    invalidCode: SuggestionCode.pubspecHomepageIsNotHelpful,
    invalidAction:
        'Create a website about the package or use the source repository URL.',
    http404Code: SuggestionCode.pubspecHomepageDoesNotExists,
    http404Penalty: 20.0,
    insecureCode: SuggestionCode.pubspecHomepageIsInsecure,
  );

  if (pubspec.documentation != null && pubspec.documentation.isNotEmpty) {
    await processUrlStatus(
      'documentation',
      'Documentation URL',
      pubspec.documentation,
      invalidCode: SuggestionCode.pubspecDocumentationIsNotHelpful,
      invalidAction:
          'Create a website about the package or remove the `documentation` key.',
      http404Code: SuggestionCode.pubspecDocumentationDoesNotExists,
      insecureCode: SuggestionCode.pubspecDocumentationIsInsecure,
    );
  }

  if (pubspec.repository != null && pubspec.repository.isNotEmpty) {
    await processUrlStatus(
      'repository',
      'Repository URL',
      pubspec.repository,
      invalidCode: SuggestionCode.pubspecRepositoryDoesNotExists,
      invalidAction: 'Use the source code repository URL.',
      http404Code: SuggestionCode.pubspecRepositoryIsNotHelpful,
      insecureCode: SuggestionCode.pubspecRepositoryIsInsecure,
    );
  }

  if (pubspec.issueTracker != null && pubspec.issueTracker.isNotEmpty) {
    await processUrlStatus(
      'issue_tracker',
      'Issue tracker URL',
      pubspec.issueTracker,
      invalidCode: SuggestionCode.pubspecIssueTrackerDoesNotExists,
      invalidAction: 'Use the issue tracker URL of the source code repository.',
      http404Code: SuggestionCode.pubspecIssueTrackerIsNotHelpful,
      insecureCode: SuggestionCode.pubspecIssueTrackerIsInsecure,
    );
  }

  if (!pubspec.hasDartSdkConstraint) {
    maintenanceSuggestions.add(Suggestion.error(
        SuggestionCode.pubspecSdkConstraintMissing,
        'Add SDK constraint in `pubspec.yaml`.',
        'For information about setting SDK constraint, please see '
        '[https://www.dartlang.org/tools/pub/pubspec#sdk-constraints](https://www.dartlang.org/tools/pub/pubspec#sdk-constraints).',
        score: 50.0));
  }

  if (pubspec.hasGitDependency) {
    final penalty = pubspec.hasUnrestrictedGitDependency ? 100.0 : 50.0;
    maintenanceSuggestions.add(Suggestion.warning(
      SuggestionCode.pubspecHasGitDependency,
      'Prefer published dependencies.',
      'The source code in a `git` repository is mutable and could disappear.',
      score: penalty,
    ));
  }

  if (pubspec.shouldWarnDart2Constraint) {
    maintenanceSuggestions.add(Suggestion.error(
        SuggestionCode.pubspecSdkConstraintDevOnly,
        'Support latest stable Dart SDK in `pubspec.yaml`.',
        'The SDK constraint in pubspec.yaml doesn\'t allow the latest stable Dart SDK release.',
        score: 20.0));
  }

  if (dartdocSuccessful == false) {
    maintenanceSuggestions.add(getDartdocRunFailedSuggestion());
  }

  if (pkgPlatform.hasConflict) {
    maintenanceSuggestions.add(Suggestion.error(
        SuggestionCode.platformConflictInPkg,
        'Fix platform conflicts.',
        pkgPlatform.reason,
        score: 20.0));
  }

  if (!changelogExists) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.changelogMissing,
        'Maintain `CHANGELOG.md`.',
        'Changelog entries help clients to follow the progress in your code.',
        score: 20.0));
  }
  if (!readmeExists) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.readmeMissing,
        'Maintain `README.md`.',
        'Readme should inform others about your project, what it does, and how they can use it.',
        score: 30.0));
  }
  if (!exampleFileExists) {
    final exampleDirExists = files.any((file) => file.startsWith('example/'));
    final commonMsg =
        'Common file name patterns include: `main.dart`, `example.dart` or you could also use `$pkgName.dart`. '
        'Packages with multiple examples should use `example/README.md`.\n\n'
        'For more information see the [pub package layout conventions](https://www.dartlang.org/tools/pub/package-layout#examples).';
    if (exampleDirExists) {
      maintenanceSuggestions.add(Suggestion.hint(
          SuggestionCode.exampleMissing,
          'Maintain an example.',
          'None of the files in your `example/` directory matches a known example patterns.\n\n'
          '$commonMsg'));
    } else {
      maintenanceSuggestions.add(Suggestion.hint(
          SuggestionCode.exampleMissing,
          'Maintain an example.',
          'Create a short demo in the `example/` directory to show how to use this package.\n\n'
          '$commonMsg',
          score: 10.0));
    }
  }
  if (oldAnalysisOptions) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.analysisOptionsRenameRequired,
        'Use `analysis_options.yaml`.',
        'Rename old `.analysis_options` file to `analysis_options.yaml`.',
        score: 10.0));
  }
  if (analysisOptionsExists && strongModeDisabled) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.analysisOptionsWeakMode,
        'The option `strong-mode: false` is being deprecated.',
        'Remove `strong-mode: false` from your `analysis_options.yaml` file:\n\n'
        '```\nanalyzer:\n  strong-mode: false\n```\n',
        score: 50.0));
  }

  final version = pubspec.version;
  final isExperimentalVersion = version.major == 0 && version.minor == 0;
  final isPreReleaseVersion = version.isPreRelease;

  // Pre-v1
  if (isExperimentalVersion) {
    maintenanceSuggestions.add(Suggestion.hint(
        SuggestionCode.packageVersionPreV01,
        'Package is pre-v0.1 release.',
        'While there is nothing inherently wrong with versions of `0.0.*`, it '
        'usually means that the author is still experimenting with the general '
        'direction of the API.',
        score: 10.0));
  }

  // Not a "gold" release
  if (isPreReleaseVersion) {
    maintenanceSuggestions.add(Suggestion.hint(
        SuggestionCode.packageVersionPreRelease,
        'Package is pre-release.',
        'Pre-release versions should be used with caution, their API may change '
        'in breaking ways.',
        score: 5.0));
  }

  // Checking the length of description.
  final description = pubspec.description?.trim();
  if (description == null || description.isEmpty) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.pubspecDescriptionTooShort,
        'Add `description` in `pubspec.yaml`.',
        'Description is critical to giving users a quick insight into the features '
        'of the package and why it is relevant to their query. '
        'Ideal length is between 60 and 180 characters.',
        score: 20.0));
  } else if (description.length < 60) {
    maintenanceSuggestions.add(Suggestion.hint(
        SuggestionCode.pubspecDescriptionTooShort,
        'The description is too short.',
        'Add more detail about the package, what it does and what is its target use case. '
        'Try to write at least 60 characters.',
        score: 20.0));
  } else if (description.length > 180) {
    maintenanceSuggestions.add(Suggestion.hint(
        SuggestionCode.pubspecDescriptionTooLong,
        'The description is too long.',
        'Search engines will display only the first part of the description. '
        'Try to keep it under 180 characters.',
        score: 10.0));
  }

  // Checking the non-English characters in the description
  if (nonAsciiRuneRatio(description) > 0.1) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.pubspecDescriptionAsciiOnly,
        'The description contains too many non-ASCII characters.',
        "The site uses English as it's primary language. Please use a "
        'description that primarily contains characters used when writing English.',
        score: 20.0));
  }

  if (unconstrainedDeps != null && unconstrainedDeps.isNotEmpty) {
    final count = unconstrainedDeps.length;
    final pluralized = count == 1 ? '1 dependency' : '$count dependencies';
    final names = unconstrainedDeps
        .map((pd) => pd.package)
        .map((name) => '`$name`')
        .join(', ');
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.pubspecDependenciesUnconstrained,
        'Use constrained dependencies.',
        'The `pubspec.yaml` contains $pluralized without version constraints. '
        'Specify version ranges for the following dependencies: $names.',
        score: 20.0));
  }

  try {
    pubspek.Pubspec.fromJson(pubspec.toJson(), lenient: false);
  } catch (e) {
    maintenanceSuggestions.add(pubspecParseError(e));
  }

  maintenanceSuggestions.sort();
  return Maintenance(
    missingChangelog: !changelogExists,
    missingReadme: !readmeExists,
    missingExample: !exampleFileExists,
    missingAnalysisOptions: !analysisOptionsExists,
    oldAnalysisOptions: oldAnalysisOptions,
    strongModeEnabled: !strongModeDisabled,
    isExperimentalVersion: isExperimentalVersion,
    isPreReleaseVersion: isPreReleaseVersion,
    dartdocSuccessful: dartdocSuccessful,
    suggestions: maintenanceSuggestions,
  );
}
