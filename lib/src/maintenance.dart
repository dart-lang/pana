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
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart' as yaml;

import 'dartdoc_analyzer.dart';
import 'download_utils.dart';
import 'markdown_content.dart';
import 'model.dart';
import 'package_analyzer.dart' show InspectOptions;
import 'pubspec.dart';
import 'utils.dart';

final Duration _year = const Duration(days: 365);
final Duration _twoYears = _year * 2;
const _defaultLargeFileKB = 128;

final List<String> changelogFileNames = textFileNameCandidates('changelog');

final List<String> readmeFileNames = textFileNameCandidates('readme');

const _pluginDocsUrl =
    'https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin';

@deprecated
final List<String> exampleReadmeFileNames = <String>[
  ...textFileNameCandidates('example/example'),
  ...textFileNameCandidates('example/readme'),
];

/// Returns the candidates in priority order to display under the 'Example' tab.
List<String> exampleFileCandidates(String package) {
  return <String>[
    ...textFileNameCandidates('example/example'),
    'example/lib/main.dart',
    'example/main.dart',
    'example/lib/$package.dart',
    'example/$package.dart',
    'example/lib/${package}_example.dart',
    'example/${package}_example.dart',
    'example/lib/example.dart',
    'example/example.dart',
    ...textFileNameCandidates('example/readme'),
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
        'The package was last published more than two years ago.',
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
        'The package was last published $ageInWeeks weeks ago.',
        score: score);
  }

  return null;
}

/// Returns a suggestion for pubspec.yaml parse error.
Suggestion pubspecParseError(error) {
  // TODO: remove this after json_annotation is updated with CheckedFromJsonException.toString()
  var message = error?.toString();
  if (error is CheckedFromJsonException) {
    final msg =
        error.message ?? 'Error with `${error.key}`: ${error.innerError}';
    message = 'CheckedFromJsonException: $msg';
  }
  return Suggestion.error(
    SuggestionCode.pubspecParseError,
    'Error while parsing `pubspec.yaml`.',
    'Parsing throw an exception:\n\n```\n$message\n```.',
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
  // TODO: remove at next major version upgrade, use [pkgResolution] instead
  List<PkgDependency> unconstrainedDeps, {
  @required PkgResolution pkgResolution,
  @required List<String> tags,
  bool dartdocSuccessful,
}) async {
  final pkgName = pubspec.name;
  final maintenanceSuggestions = <Suggestion>[];
  final files = await listFiles(pkgDir).toList();
  final hasPublicDartLibrary = files.any((path) =>
      path.startsWith('lib/') &&
      !path.startsWith('lib/src/') &&
      path.endsWith('.dart'));

  Future<File> firstExistingFile(
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
        if (length >= minLength) {
          return file;
        }
      }
    }
    return null;
  }

  final changelogFile = await firstExistingFile(changelogFileNames);
  final readmeFile = await firstExistingFile(readmeFileNames);
  final exampleFile = await firstExistingFile(exampleFileCandidates(pkgName));
  final analysisOptionsFile =
      await firstExistingFile(analysisOptionsFiles, caseSensitive: true);
  final oldAnalysisOptions = analysisOptionsFile != null &&
      !files.contains(currentAnalysisOptionsFileName);
  var strongModeDisabled = false;
  if (analysisOptionsFile != null) {
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
              "The analyzer can't parse `$name`.",
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
        "$name isn't helpful.",
        invalidAction,
        score: invalidPenalty,
      ));
    } else if (status == UrlStatus.missing) {
      maintenanceSuggestions.add(Suggestion.warning(
        http404Code,
        "$name doesn't exist.",
        'At the time of the analysis the `$key` field `$url` was unreachable.',
        score: http404Penalty,
      ));
    } else if (status == UrlStatus.exists && !url.startsWith('https://')) {
      maintenanceSuggestions.add(Suggestion.hint(
        insecureCode,
        '$name is insecure.',
        'Update the `$key` field and use a secure (`https`) URL.',
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
        'Update the `homepage` field from `pubspec.yaml`: link to a website '
        'about the package or use the source repository URL.',
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
          'Either remove the `documentation` field from `pubspec.yaml`, or '
          'update it to link to a website about the package.',
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
      invalidAction:
          'Either remove the `repository` field from `pubspec.yaml`, or '
          'update it to link to the source code repository.',
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
      invalidAction:
          'Either remove the `repository` field from `pubspec.yaml`, or '
          'update it to link to the issue tracker of the source code repository.',
      http404Code: SuggestionCode.pubspecIssueTrackerIsNotHelpful,
      insecureCode: SuggestionCode.pubspecIssueTrackerIsInsecure,
    );
  }

  if (!pubspec.hasDartSdkConstraint) {
    maintenanceSuggestions.add(Suggestion.error(
        SuggestionCode.pubspecSdkConstraintMissing,
        'Add an `sdk` field to `pubspec.yaml`.',
        'For information about setting the SDK constraint, see '
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
        'Support future stable Dart 2 SDKs in `pubspec.yaml`.',
        'The SDK constraint in `pubspec.yaml` doesn\'t allow future stable Dart 2.x SDK releases.',
        score: 20.0));
  }

  if (pubspec.usesOldFlutterPluginFormat) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.pubspecUsesOldFlutterPluginFormat,
        'Update flutter plugin descriptor in `pubspec.yaml`.',
        'In pubspec.yaml the '
            'flutter.plugin.{androidPackage,iosPrefix,pluginClass} keys are '
            'deprecated. Consider using the flutter.plugin.platforms key '
            'introduced in Flutter 1.10.0\n\n See $_pluginDocsUrl',
        score: 10.0));
  }

  if (dartdocSuccessful == false) {
    maintenanceSuggestions.add(getDartdocRunFailedSuggestion());
  }

  if (tags == null ||
      tags.isEmpty ||
      tags.every((tag) => !tag.startsWith('sdk:'))) {
    maintenanceSuggestions.add(Suggestion.error(
        SuggestionCode.sdkMissing,
        'No valid SDK.',
        'The analysis could not detect a valid SDK that can use this package.',
        score: 20.0));
  }

  Future checkFileLength(File file, String code,
      {int limitInKB = _defaultLargeFileKB}) async {
    if (file == null || !file.existsSync()) return;
    final length = await file.length();
    final lengthInKB = length / 1024.0;
    final lengthPenalty = lengthInKB - limitInKB;
    if (lengthPenalty > 0.0) {
      final relativePath = p.relative(file.path, from: pkgDir);
      maintenanceSuggestions.add(Suggestion.warning(
        code,
        '`$relativePath` too large.',
        'Try to keep the file size under ${limitInKB}k.',
        file: relativePath,
        score: lengthPenalty,
      ));
    }
  }

  await checkFileLength(
    File(p.join(pkgDir, 'pubspec.yaml')),
    SuggestionCode.pubspecTooLarge,
    limitInKB: 32,
  );

  if (changelogFile == null) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.changelogMissing,
        'Provide a file named `CHANGELOG.md`.',
        'Changelog entries help developers follow the progress of your package. '
            'See the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/CHANGELOG.md) generated by `stagehand`.',
        score: 20.0));
  } else {
    await checkFileLength(changelogFile, SuggestionCode.changelogTooLarge);
    if (_isMarkdown(changelogFile.path)) {
      final suggestion =
          await analyzeMarkdownFile(changelogFile, pkgDir: pkgDir);
      if (suggestion != null) {
        maintenanceSuggestions.add(suggestion);
      }
    }
  }

  if (readmeFile == null) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.readmeMissing,
        'Provide a file named `README.md`.',
        'The `README.md` file should inform others about your project, what it does, and how they can use it. '
            'See the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/README.md) generated by `stagehand`.',
        score: 30.0));
  } else {
    await checkFileLength(readmeFile, SuggestionCode.readmeTooLarge);
    if (_isMarkdown(readmeFile.path)) {
      final suggestion = await analyzeMarkdownFile(readmeFile, pkgDir: pkgDir);
      if (suggestion != null) {
        maintenanceSuggestions.add(suggestion);
      }
    }
  }

  if (exampleFile == null) {
    final exampleDirExists = files.any((file) => file.startsWith('example/'));
    final commonMsg =
        'Common filename patterns include `main.dart`, `example.dart`, and `$pkgName.dart`. '
        'Packages with multiple examples should provide `example/README.md`.\n\n'
        'For more information see the [pub package layout conventions](https://www.dartlang.org/tools/pub/package-layout#examples).';
    if (exampleDirExists) {
      maintenanceSuggestions.add(Suggestion.hint(
          SuggestionCode.exampleMissing,
          'Maintain an example.',
          "None of the files in the package's `example/` directory matches known example patterns.\n\n"
              '$commonMsg'));
    } else if (hasPublicDartLibrary) {
      maintenanceSuggestions.add(Suggestion.hint(
          SuggestionCode.exampleMissing,
          'Maintain an example.',
          'Create a short demo in the `example/` directory to show how to use this package.\n\n'
              '$commonMsg',
          score: 10.0));
    }
  } else {
    await checkFileLength(exampleFile, SuggestionCode.exampleTooLarge);
    if (_isMarkdown(exampleFile.path)) {
      final suggestion = await analyzeMarkdownFile(exampleFile, pkgDir: pkgDir);
      if (suggestion != null) {
        maintenanceSuggestions.add(suggestion);
      }
    }
  }

  if (oldAnalysisOptions) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.analysisOptionsRenameRequired,
        'Use `analysis_options.yaml`.',
        "Change the name of your package's `.analysis_options` file to `analysis_options.yaml`.",
        score: 10.0));
  }
  if (analysisOptionsFile != null && strongModeDisabled) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.analysisOptionsWeakMode,
        'The option `strong-mode: false` is deprecated.',
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
        'While nothing is inherently wrong with versions of `0.0.*`, it might '
            'mean that the author is still experimenting with the general '
            'direction of the API.',
        score: 10.0));
  }

  // Not a "gold" release
  if (isPreReleaseVersion) {
    maintenanceSuggestions.add(Suggestion.hint(
        SuggestionCode.packageVersionPreRelease,
        'Package is pre-release.',
        'Pre-release versions should be used with caution; their API can change '
            'in breaking ways.',
        score: 5.0));
  }

  // Checking the length of description.
  final description = pubspec.description?.trim();
  if (description == null || description.isEmpty) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.pubspecDescriptionTooShort,
        'Add `description` in `pubspec.yaml`.',
        'The description gives users information about the features of your '
            'package and why it is relevant to their query. We recommend a '
            'description length of 60 to 180 characters.',
        score: 20.0));
  } else if (description.length < 60) {
    final penalty = min(20.0, 60.0 - description.length);
    maintenanceSuggestions.add(Suggestion.hint(
        SuggestionCode.pubspecDescriptionTooShort,
        'The package description is too short.',
        'Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 '
            'characters to describe the package, what it does, and its target use case.',
        score: penalty));
  } else if (description.length > 180) {
    final penalty = min(10.0, description.length - 180.0);
    maintenanceSuggestions.add(Suggestion.hint(
        SuggestionCode.pubspecDescriptionTooLong,
        'The description is too long.',
        'Search engines display only the first part of the description. '
            "Try to keep the value of the `description` field in your package's "
            '`pubspec.yaml` file between 60 and 180 characters.',
        score: penalty));
  }

  // Checking the non-English characters in the description
  if (nonAsciiRuneRatio(description) > 0.1) {
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.pubspecDescriptionAsciiOnly,
        'The description contains too many non-ASCII characters.',
        'The site uses English as its primary language. The value of the '
            "`description` field in your package's `pubspec.yaml` field should "
            'primarily contain characters used in English.',
        score: 20.0));
  }

  // Checking the dependencies that have no constraints.
  unconstrainedDeps ??= pkgResolution?.getUnconstrainedDeps(onlyDirect: true);
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

  // Checking the direct dependencies that can't be used with their latest version.
  final outdatedPackages = pkgResolution?.outdated
          ?.where((pd) => pd.isDirect)
          ?.where((pd) => !pd.constraint.allows(pd.available))
          ?.map((p) => p.package)
          ?.toList() ??
      <PkgDependency>[];
  if (outdatedPackages.isNotEmpty) {
    final count = outdatedPackages.length;
    final pluralized = count == 1 ? '1 dependency' : '$count dependencies';
    final penalty = count * 10.0;
    final extraDescr = ' (${outdatedPackages.map((s) => '`$s`').join(', ')})';
    maintenanceSuggestions.add(Suggestion.warning(
        SuggestionCode.pubspecDependenciesOutdated,
        'Support latest dependencies.',
        'The version constraint in `pubspec.yaml` does not support the latest '
            'published versions for $pluralized'
            '$extraDescr.',
        score: penalty));
  }

  try {
    pubspek.Pubspec.fromJson(pubspec.toJson(), lenient: false);
  } catch (e) {
    maintenanceSuggestions.add(pubspecParseError(e));
  }

  maintenanceSuggestions.sort();
  return Maintenance(
    missingChangelog: changelogFile == null,
    missingReadme: readmeFile == null,
    missingExample: exampleFile == null,
    missingAnalysisOptions: analysisOptionsFile == null,
    oldAnalysisOptions: oldAnalysisOptions,
    strongModeEnabled: !strongModeDisabled,
    isExperimentalVersion: isExperimentalVersion,
    isPreReleaseVersion: isPreReleaseVersion,
    dartdocSuccessful: dartdocSuccessful,
    suggestions: maintenanceSuggestions,
  );
}

bool _isMarkdown(String fileName) =>
    p.extension(fileName).toLowerCase() == '.md';
