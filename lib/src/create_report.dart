// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart'
    show
        Dependency,
        GitDependency,
        HostedDependency,
        PathDependency,
        SdkDependency;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../models.dart';
import '../pana.dart';
import 'logging.dart';
import 'markdown_content.dart';
import 'package_context.dart';
import 'pubspec.dart';
import 'tag_detection.dart';

const _pluginDocsUrl =
    'https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin';

/// We currently don't have flutter installed on travis. So we emulate having
/// no Flutter installed when generating golden files.
// TODO(sigurdm): try to get Flutter on travis.
var isRunningEnd2EndTest = false;

Future<Report> createReport(PackageContext context) async {
  Pubspec pubspec;
  try {
    pubspec = context.pubspec;
  } on Exception catch (e) {
    return Report(
      sections: [
        ReportSection(
          id: ReportSectionId.convention,
          grantedPoints: 0,
          maxPoints: 100,
          title: 'Failed to parse the pubspec',
          summary: e.toString(),
          status: ReportStatus.failed,
        )
      ],
    );
  }

  return Report(sections: [
    await _followsTemplate(context),
    await _hasDocumentation(context.packageDir, pubspec),
    await _multiPlatform(context.packageDir, pubspec),
    await _staticAnalysis(context),
    await _trustworthyDependency(context),
    if (context.options.nullSafetySectionEnabledBeforeOptin ||
        pubspec.sdkConstraintStatus.hasOptedIntoNullSafety)
      await _nullSafety(context.packageDir, pubspec),
  ]);
}

Future<ReportSection> _hasDocumentation(
    String packageDir, Pubspec pubspec) async {
  // TODO: run dartdoc for coverage

  final candidates = exampleFileCandidates(pubspec.name, caseSensitive: true);
  final examplePath = candidates.firstWhere(
      (c) => File(p.join(packageDir, c)).existsSync(),
      orElse: () => null);
  final issues = <_Issue>[
    if (examplePath == null)
      _Issue(
        'No example found.',
        suggestion:
            'See [package layout](https://dart.dev/tools/pub/package-layout#examples) '
            'guidelines on how to add an example.',
      )
    else
      _Issue('Found example at: `$examplePath`')
  ];

  final points = examplePath == null ? 0 : 10;
  final status =
      examplePath == null ? ReportStatus.failed : ReportStatus.passed;
  return _makeSection(
    id: ReportSectionId.documentation,
    title: documentationSectionTitle,
    maxPoints: 10,
    subsections: [
      _Subsection('Package has an example', issues, points, 10, status)
    ],
    basePath: null,
  );
}

Future<ReportSection> _staticAnalysis(PackageContext context) async {
  final packageDir = context.packageDir;
  final analysisResult = await _analyzePackage(context);

  final errors = analysisResult.errors;
  final warnings = analysisResult.warnings;
  final lints = analysisResult.lints;

  // Only try to run dartfmt if there where no errors.
  final formattingIssues = errors.isEmpty
      ? await _formatPackage(packageDir, context.toolEnvironment,
          usesFlutter: context.usesFlutter)
      : <_Issue>[];

  final status = (errors.isEmpty && warnings.isEmpty)
      ? (formattingIssues.isEmpty && lints.isEmpty
          ? ReportStatus.passed
          : ReportStatus.partial)
      : ReportStatus.failed;

  // 10 points: static analysis has 0 errors
  // 20 points: static analysis has 0 errors, warnings
  // 30 points: static analysis has 0 errors, warnings, lints
  var grantedPoints = 0;
  if (errors.isEmpty) {
    grantedPoints = 10;
    if (warnings.isEmpty) {
      grantedPoints = 20;
      if (lints.isEmpty && formattingIssues.isEmpty) {
        grantedPoints = 30;
      }
    }
  }
  return _makeSection(
    id: ReportSectionId.analysis,
    title: 'Pass static analysis',
    maxPoints: 30,
    subsections: [
      _Subsection(
        'code has no errors, warnings, lints, or formatting issues',
        [...errors, ...warnings, ...lints, ...formattingIssues],
        grantedPoints,
        30,
        status,
      )
    ],
    basePath: packageDir,
  );
}

Future<_AnalysisResult> _analyzePackage(PackageContext context) async {
  _Issue issueFromCodeProblem(CodeProblem codeProblem) {
    return _Issue(
      '${codeProblem.severity}: ${codeProblem.description}',
      // TODO(sigurdm) update this to `dart analyze` after 2.9.
      suggestion:
          'To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and '
          'run `${context.usesFlutter ? 'flutter analyze' : 'dartanalyzer'} ${codeProblem.file}`',
      spanFn: () {
        final sourceFile = SourceFile.fromString(
            File(p.join(context.packageDir, codeProblem.file))
                .readAsStringSync(),
            url: p.join(context.packageDir, codeProblem.file));
        try {
          // SourceSpans are 0-based, so we subtract 1 from line and column.
          final startOffset =
              sourceFile.getOffset(codeProblem.line - 1, codeProblem.col - 1);
          return sourceFile.span(startOffset, startOffset + codeProblem.length);
        } on RangeError {
          // Note: This happens if the file contains CR as line terminators.
          // If the range is invalid, then we just return null.
          return null;
        }
      },
    );
  }

  final dirs = await listFocusDirs(context.packageDir);

  try {
    final list = await context.staticAnalysis();

    return _AnalysisResult(
        list
            .where((element) => element.isError)
            .map(issueFromCodeProblem)
            .toList(),
        list
            .where((element) => element.isWarning)
            .map(issueFromCodeProblem)
            .toList(),
        list
            .where((element) => element.isInfo)
            .map(issueFromCodeProblem)
            .toList(),
        'dartanalyzer ${dirs.join(' ')}');
  } on ToolException catch (e) {
    return _AnalysisResult(
      [
        _Issue('Failed to run `dartanalyzer`:\n```\n${e.message}\n```\n'),
      ],
      [],
      [],
      'dartanalyzer ${dirs.join(' ')}',
    );
  }
}

class _AnalysisResult {
  final List<_Issue> errors;
  final List<_Issue> warnings;
  final List<_Issue> lints;
  final String reproductionCommand;

  _AnalysisResult(
      this.errors, this.warnings, this.lints, this.reproductionCommand);
}

Future<List<_Issue>> _formatPackage(
  String packageDir,
  ToolEnvironment toolEnvironment, {
  @required bool usesFlutter,
}) async {
  try {
    final unformattedFiles = await toolEnvironment.filesNeedingFormat(
      packageDir,
      usesFlutter,
    );
    return unformattedFiles
        .map((f) => _Issue('$f is not formatted according to dartfmt',
            suggestion: 'To format your files run: `dartfmt -w .`'))
        .toList();
  } on ToolException catch (e) {
    return [
      _Issue('Running `dartfmt` failed:\n```\n${e.message}```'),
    ];
  } catch (e, stack) {
    log.severe('`dartfmt` failed.\n$e', e, stack);
    return [
      _Issue('Running `dartfmt` failed.'),
    ];
  }
}

Future<ReportSection> _followsTemplate(PackageContext context) async {
  final options = context.options;
  final packageDir = context.packageDir;
  final pubspec = context.pubspec;

  Future<List<_Issue>> findUrlIssues(
    String key,
    String name, {
    bool isRequired = false,
  }) async {
    final content = pubspec.originalYaml[key];
    if (content != null && content is! String) {
      return [
        _Issue(
            'The `$key` entry, if present, should be a string containing a url',
            span: _tryGetSpanFromYamlMap(pubspec.originalYaml, key))
      ];
    }
    final url = content as String;
    final issues = <_Issue>[];

    if (url == null || url.isEmpty) {
      if (isRequired) {
        issues.add(
          _Issue("`pubspec.yaml` doesn't have a `$key` entry."),
        );
      }
      return issues;
    }

    final status = await context.urlChecker.checkStatus(
      url,
      isInternalPackage: options.isInternal,
    );
    if (status == UrlStatus.invalid || status == UrlStatus.internal) {
      issues.add(
        _Issue(
          "$name isn't helpful.",
          span: _tryGetSpanFromYamlMap(pubspec.originalYaml, key),
        ),
      );
    } else if (status == UrlStatus.missing) {
      issues.add(
        _Issue(
          "$name doesn't exist.",
          span: _tryGetSpanFromYamlMap(pubspec.originalYaml, key),
          suggestion: 'At the time of the analysis `$url` was unreachable.',
        ),
      );
    } else if (status == UrlStatus.exists && !url.startsWith('https://')) {
      issues.add(
        _Issue(
          '$name is insecure.',
          span: _tryGetSpanFromYamlMap(pubspec.originalYaml, key),
          suggestion: 'Update the `$key` field and use a secure (`https`) URL.',
        ),
      );
    }
    return issues;
  }

  List<_Issue> findFileSizeIssues(File file,
      {int limitInKB = 128, String missingSuggestion}) {
    final length = file.lengthSync();
    final lengthInKB = length / 1024.0;
    return [
      if (length == 0)
        _Issue('${p.relative(file.path, from: packageDir)} is empty.',
            suggestion: missingSuggestion),
      if (lengthInKB > limitInKB)
        _Issue(
          '${p.relative(file.path, from: packageDir)} too large.',
          suggestion: 'Try to keep the file size under ${limitInKB}k.',
        )
    ];
  }

  /// Analyze a markdown file and return suggestions.
  Future<List<_Issue>> findMarkdownIssues(File file) async {
    final issues = <_Issue>[];
    final filename = p.basename(file.path);
    final analysis = await scanMarkdownFileContent(file);
    Future<void> findLinkIssues(List<Link> links, String linkType) async {
      final checked = await checkLinks(links);
      // TODO: warn about relative image URLs
      // TODO: warn about relative links
      // TODO: consider checking whether the URL exists and returns HTTP 200.

      if (checked.unparsed.isNotEmpty) {
        final count = checked.unparsed.length;
        final first = checked.unparsed.first;
        final s = count == 1 ? '' : 's';
        issues.add(_Issue(
            'Links in `$filename` should be well formed '
            'Unable to parse $count image link$s.',
            span: first.span));
      }
      if (checked.insecure.isNotEmpty) {
        final count = checked.insecure.length;
        final first = checked.insecure.first;
        final sAre = count == 1 ? ' is' : 's are';
        issues.add(_Issue(
            'Links in `$filename` should be secure. $count $linkType$sAre insecure.',
            suggestion: 'Use `https` URLs instead.',
            span: first.span));
      }
    }

    await findLinkIssues(analysis.links, 'link');
    await findLinkIssues(analysis.images, 'image link');
    if (analysis.isMalformedUtf8) {
      issues.add(_Issue(
        '`$filename` is not a valid UTF-8 file.',
        suggestion:
            'The content of `$filename` in your package should contain valid UTF-8 characters.',
      ));
    }
    if (analysis.nonAsciiRatio > 0.2) {
      issues.add(_Issue(
        '`$filename` contains too many non-ASCII characters.',
        suggestion:
            'The site uses English as its primary language. The content of '
            '`$filename` in your package should primarily contain characters used in English.',
      ));
    }

    return issues;
  }

  Future<_Subsection> checkPubspec() async {
    final issues = <_Issue>[];
    if (pubspec.hasUnknownSdks) {
      issues.add(_Issue('Unknown SDKs in `pubspec.yaml`.',
          span: _tryGetSpanFromYamlMap(
              pubspec.environment, pubspec.unknownSdks.first),
          suggestion: 'The following unknown SDKs are in `pubspec.yaml`:\n'
              '`${pubspec.unknownSdks}`.\n\n'
              '`pana` doesn’t recognize them; please remove the `sdk` entry.'));
    }
    issues.addAll(await findUrlIssues('homepage', 'Homepage URL',
        isRequired: pubspec.repository == null));
    issues.addAll(await findUrlIssues('repository', 'Repository URL',
        isRequired: pubspec.homepage == null));
    issues.addAll(await findUrlIssues('documentation', 'Documentation URL'));
    issues.addAll(await findUrlIssues('issue_tracker', 'Issue tracker URL'));
    final gitDependencies =
        pubspec.dependencies.entries.where((e) => e.value is GitDependency);
    if (gitDependencies.isNotEmpty) {
      issues.add(_Issue(
        'The package has a git dependency.',
        span: _tryGetSpanFromYamlMap(
            pubspec.originalYaml['dependencies'] as Map,
            gitDependencies.first.key),
        suggestion: "The pub site doesn't allow git dependencies.",
      ));
    }

    if (pubspec.usesOldFlutterPluginFormat) {
      issues.add(
        _Issue(
          'Flutter plugin descriptor uses old format.',
          span: _tryGetSpanFromYamlMap(
              pubspec.originalYaml['flutter'] as Map, 'plugin'),
          suggestion:
              'The flutter.plugin.{androidPackage,iosPrefix,pluginClass} keys are '
              'deprecated. Consider using the flutter.plugin.platforms key '
              'introduced in Flutter 1.10.0\n\n See $_pluginDocsUrl',
        ),
      );
    }

    if (pubspec.shouldWarnDart2Constraint) {
      issues.add(
        _Issue(
          "Sdk-constraint doesn't allow future stable dart 2.x releases",
          span: _tryGetSpanFromYamlMap(
            pubspec.environment,
            'sdk',
          ),
        ),
      );
    }

    // Checking the length of description.
    final description = pubspec.description?.trim();
    final span = _tryGetSpanFromYamlMap(pubspec.originalYaml, 'description');
    if (description == null || description.isEmpty) {
      issues.add(
        _Issue(
          'Add `description` in `pubspec.yaml`.',
          span: span,
          suggestion:
              'The description gives users information about the features of your '
              'package and why it is relevant to their query. We recommend a '
              'description length of 60 to 180 characters.',
        ),
      );
    } else if (description.length < 60) {
      issues.add(
        _Issue('The package description is too short.',
            span: span,
            suggestion:
                'Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 '
                'characters to describe the package, what it does, and its target use case.'),
      );
    } else if (description.length > 180) {
      issues.add(
        _Issue('The package description is too long.',
            span: span,
            suggestion:
                'Search engines display only the first part of the description. '
                "Try to keep the value of the `description` field in your package's "
                '`pubspec.yaml` file between 60 and 180 characters.'),
      );
    }

    // characters in description
    if (nonAsciiRuneRatio(description) > 0.1) {
      issues.add(_Issue(
        'The package description contains too many non-ASCII characters.',
        span: span,
        suggestion:
            'The site uses English as its primary language. The content of the '
            "`description` field in your package's `pubspec.yaml` should "
            'primarily contain characters used in English.',
      ));
    }

    issues.addAll(findFileSizeIssues(File(p.join(packageDir, 'pubspec.yaml')),
        limitInKB: 32));

    final status = issues.isEmpty ? ReportStatus.passed : ReportStatus.failed;
    final points = issues.isEmpty ? 10 : 0;
    return _Subsection(
      'Provide a valid `pubspec.yaml`',
      issues,
      points,
      10,
      status,
    );
  }

  Future<_Subsection> checkAsset(
    String filename,
    String missingSuggestion,
  ) async {
    final fullPath = p.join(packageDir, filename);
    final file = File(fullPath);
    final issues = <_Issue>[];

    if (!file.existsSync()) {
      issues.add(
        _Issue('No `$filename` found.', suggestion: missingSuggestion),
      );
    } else {
      issues.addAll(
          findFileSizeIssues(file, missingSuggestion: missingSuggestion));
      issues.addAll(await findMarkdownIssues(file));
    }
    final status = issues.isEmpty ? ReportStatus.passed : ReportStatus.failed;
    final points = issues.isEmpty ? 5 : 0;
    return _Subsection(
      'Provide a valid `$filename`',
      issues,
      points,
      5,
      status,
    );
  }

  final readmeSubsection = await checkAsset(
    'README.md',
    'The `README.md` file should inform others about your project, what it does, and how they can use it. '
        'See: the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/README.md) generated by `stagehand`.',
  );
  final changelogSubsection = await checkAsset(
    'CHANGELOG.md',
    'Changelog entries help developers follow the progress of your package. '
        'See the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/CHANGELOG.md) generated by `stagehand`.',
  );
  final pubspecSection = await checkPubspec();
  final subsections = [pubspecSection, readmeSubsection, changelogSubsection];
  return _makeSection(
    id: ReportSectionId.convention,
    title: 'Follow Dart file conventions',
    maxPoints: 20,
    subsections: subsections,
    basePath: packageDir,
    maxIssues: 10,
  );
}

SourceSpan _tryGetSpanFromYamlMap(Object map, String key) {
  if (map is YamlMap) {
    return map.nodes[key]?.span;
  }
  return null;
}

Future<ReportSection> _trustworthyDependency(PackageContext context) async {
  final pubspec = context.pubspec;
  final packageDir = context.packageDir;
  final toolEnvironment = context.toolEnvironment;
  Future<_Subsection> dependencies() async {
    final issues = <_Issue>[];
    var bodyPrefix = '';
    if (context.pubspecAllowsCurrentSdk) {
      try {
        final outdated = Outdated.fromJson(await toolEnvironment.runPubOutdated(
          packageDir,
          args: [
            '--json',
            '--up-to-date',
            '--no-dev-dependencies',
            '--no-dependency-overrides',
          ],
        ));

        bool isOutdated(OutdatedPackage package) {
          final name = package.package;
          final latest = package?.latest?.version;
          if (pubspec.dependencies.containsKey(name) && latest != null) {
            final latestVersion = Version.parse(latest);
            final dependency = pubspec.dependencies[name];
            if (dependency is HostedDependency &&
                !dependency.version.allows(latestVersion)) {
              return true;
            }
          }
          return false;
        }

        String constraint(Dependency dependency) {
          if (dependency is HostedDependency) {
            return '`${dependency.version}`';
          } else if (dependency is SdkDependency) {
            return '`${dependency.sdk}`';
          } else if (dependency is GitDependency) {
            return '`${dependency.ref}`';
          } else if (dependency is PathDependency) {
            return '`${dependency.path}`';
          } else {
            return '-';
          }
        }

        String makeTable(List<List<String>> rows) {
          return [
            ['Package', 'Constraint', 'Compatible', 'Latest'],
            [':-', ':-', ':-', ':-'],
            ...rows,
          ].map((r) => '|${r.join('|')}|').join('\n');
        }

        final links = <String>[];
        String linkToPackage(String pkg) {
          final link = '[`$pkg`]: https://pub.dev/packages/$pkg';
          if (!links.contains(link)) {
            links.add(link);
          }
          return '[`$pkg`]';
        }

        final depsTable = outdated.packages
            .where((p) => pubspec.dependencies.containsKey(p.package))
            .map((p) => [
                  linkToPackage(p.package),
                  constraint(pubspec.dependencies[p.package]),
                  p.upgradable?.version ?? '-',
                  if (isOutdated(p))
                    '**${p.latest?.version ?? '-'}**'
                  else
                    p.latest?.version ?? '-',
                ])
            .toList();

        final transitiveTable = outdated.packages
            .where((p) => !pubspec.dependencies.containsKey(p.package))
            // See: https://github.com/dart-lang/pub/issues/2552
            .where((p) => p.upgradable != null)
            .map((p) => [
                  linkToPackage(p.package),
                  '-',
                  p.upgradable?.version ?? '-',
                  p.latest?.version ?? '-',
                ])
            .toList();

        bodyPrefix = [
          // If we have deps show table
          if (depsTable.isNotEmpty) ...[
            makeTable(depsTable),
            '',
          ] else ...[
            'No dependencies.',
            '',
          ],
          // If we have transitive deps too
          if (transitiveTable.isNotEmpty) ...[
            '<details><summary>Transitive dependencies</summary>',
            '',
            makeTable(transitiveTable),
            '</details>',
            '',
          ],
          'To reproduce run `pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.',
          '',
          if (links.isNotEmpty) ...[
            ...links,
            '',
          ],
        ].join('\n');

        issues.addAll(outdated.packages.where(isOutdated).map((p) {
          // If outdated it's always a HostedDependency in pubspec.yaml
          final dep = pubspec.dependencies[p.package] as HostedDependency;
          return _Issue(
            'The constraint `${dep.version}` on ${p.package} does not support '
            'the latest published version `${p?.latest?.version}`',
            span: _tryGetSpanFromYamlMap(
                pubspec.originalYaml['dependencies'], p.package),
          );
        }));
      } on ToolException catch (e) {
        issues.add(_Issue('Could not run pub outdated: ${e.message}'));
      }
    } else {
      issues.add(_unsupportedDartSdk(context, command: 'pub outdated'));
    }
    final status =
        issues.isNotEmpty ? ReportStatus.failed : ReportStatus.passed;
    final points = issues.isNotEmpty ? 0 : 10;

    return _Subsection(
      'All of the package dependencies are supported in the latest version',
      issues,
      points,
      10,
      status,
      bodyPrefix: bodyPrefix,
    );
  }

  Future<_Subsection> sdkSupport() async {
    final issues = <_Issue>[];
    final sdkConstraint = pubspec.dartSdkConstraint;
    if (sdkConstraint == null) {
      issues.add(_Issue('Pubspec.yaml does not have an sdk version constraint.',
          suggestion: 'Try adding an sdk constraint to your `pubspec.yaml`'));
    } else if (!context.pubspecAllowsCurrentSdk) {
      issues.add(_unsupportedDartSdk(context,
          suggestion: 'Try widening the upper boundary of the constraint.'));
    }

    final flutterVersions = toolEnvironment.runtimeInfo.flutterVersions;

    if (isRunningEnd2EndTest || flutterVersions == null) {
      issues.add(_Issue(
          'Found no Flutter in your PATH. Could not determine the current Flutter version.'));
    } else {
      final usesFlutter = pubspec.usesFlutter;

      final flutterDartVersion = Version.parse(
          (flutterVersions['dartSdkVersion'] as String).split(' ').first);
      final allowsCurrentFlutterDart =
          sdkConstraint?.allows(flutterDartVersion) ?? false;

      if (!allowsCurrentFlutterDart) {
        issues.add(
          _Issue(
            'The current SDK constraint does not allow the Dart version used by the latest stable Flutter ($flutterDartVersion)',
            span: _tryGetSpanFromYamlMap(pubspec.environment, 'sdk'),
          ),
        );
      } else {
        if (usesFlutter) {
          // TODO(sigurdm): this will not work well locally (installed version will
          // not be latest). Perhaps we should query somewhere for the latest version.
          final currentFlutterVersion =
              Version.parse(flutterVersions['frameworkVersion'] as String);
          final flutterConstraint = pubspec.flutterSdkConstraint;
          if (flutterConstraint != null &&
              !flutterConstraint.allows(currentFlutterVersion)) {
            issues.add(
              _Issue(
                'The current flutter constraint does not allow the latest Flutter ($currentFlutterVersion)',
                span: _tryGetSpanFromYamlMap(pubspec.environment, 'flutter'),
              ),
            );
          }
        }
      }
    }
    final status = issues.isEmpty ? ReportStatus.passed : ReportStatus.failed;
    final points = issues.isEmpty ? 10 : 0;
    return _Subsection(
      'Package supports latest stable Dart and Flutter SDKs',
      issues,
      points,
      10,
      status,
    );
  }

  final dependencySection = await dependencies();
  final sdkSection = await sdkSupport();
  final subsections = [dependencySection, sdkSection];
  return _makeSection(
    id: ReportSectionId.dependency,
    title: 'Support up-to-date dependencies',
    maxPoints: 20,
    subsections: subsections,
    basePath: packageDir,
  );
}

_Issue _explanationToIssue(Explanation explanation) =>
    _Issue(explanation.finding, suggestion: explanation.explanation);

Future<ReportSection> _nullSafety(String packageDir, Pubspec pubspec) async {
  // TODO(sigurdm): Currently we don't give any points for null-safety.
  // Raise this after null-safety beta.
  const maxPoints = 0;

  _Subsection subsection;
  if (File(p.join(packageDir, '.dart_tool', 'package_config.json'))
      .existsSync()) {
    final tagger = Tagger(packageDir);

    final nullSafetyTags = <String>[];
    final explanations = <Explanation>[];
    tagger.nullSafetyTags(nullSafetyTags, explanations);
    if (pubspec.sdkConstraintStatus.hasOptedIntoNullSafety) {
      if (nullSafetyTags.contains('is:null-safe')) {
        subsection = _Subsection(
            'Package and dependencies are fully migrated to null-safety',
            explanations.map(_explanationToIssue).toList(),
            maxPoints,
            maxPoints,
            ReportStatus.passed);
      } else {
        subsection = _Subsection(
            'Package declares support for null-safety, but there are issues',
            [
              ...explanations.map(_explanationToIssue).toList(),
              _Issue('For more information',
                  suggestion: 'Try running `pub outdated --mode=null-safety`.\n'
                      'Be sure to read the [migration guide](https://dart.dev/null-safety/migration-guide).')
            ],
            0,
            maxPoints,
            ReportStatus.failed);
      }
    } else {
      subsection = _Subsection(
          'Package does not opt in to null-safety',
          [
            _Issue(
              'Package language version (indicated by the sdk constraint) is less than 2.12',
              suggestion:
                  'Consider [migrating](https://dart.dev/null-safety/migration-guide).',
            )
          ],
          0,
          maxPoints,
          ReportStatus.partial);
    }
  } else {
    subsection = _Subsection(
      'Unable to detect null safety',
      [
        _Issue('Package resolution failed. Could not determine null-safety.',
            suggestion: 'Run `pub get` for more information.')
      ],
      0,
      maxPoints,
      ReportStatus.failed,
    );
  }
  return _makeSection(
    title: 'Package supports null-safety',
    maxPoints: maxPoints,
    id: ReportSectionId.nullSafety,
    subsections: [subsection],
    basePath: packageDir,
    maxIssues:
        100, // Tagging produces a bounded number of issues. Better display them all.
  );
}

Future<ReportSection> _multiPlatform(String packageDir, Pubspec pubspec) async {
  _Subsection subsection;
  if (File(p.join(packageDir, '.dart_tool', 'package_config.json'))
      .existsSync()) {
    final tags = <String>[];
    final explanations = <Explanation>[];
    final tagger = Tagger(packageDir);
    final sdkTags = <String>[];
    final sdkExplanations = <Explanation>[];
    tagger.sdkTags(sdkTags, sdkExplanations);

    final flutterPackage = pubspec.usesFlutter;

    String platformList(List<String> tags, Map<String, String> tagNames) {
      return tagNames.entries.map((entry) {
        if (tags.contains(entry.key)) {
          return '**${entry.value}**';
        } else {
          return entry.value;
        }
      }).join(', ');
    }

    _Subsection scorePlatforms(
        Map<String, String> tagNames,
        ReportStatus Function(int) statusFromCount,
        List<String> tags,
        List<Explanation> explanations) {
      final unofficialExplanations = explanations.where((e) =>
          !tags.contains(e.tag) &&
          (e.tag != null && !tagNames.containsKey(e.tag)));
      final officialExplanations = explanations.where((e) =>
          !tags.contains(e.tag) &&
          (e.tag == null || tagNames.containsKey(e.tag)));
      final trustExplanations = explanations.where((e) => tags.contains(e.tag));
      final paragraphs = [
        if (officialExplanations.isNotEmpty)
          _RawParagraph('Consider supporting multiple platforms:\n'),
        ...officialExplanations.map(_explanationToIssue),
        if (unofficialExplanations.isNotEmpty)
          _RawParagraph('\nConsider supporting these prerelease platforms:\n'),
        ...unofficialExplanations.map(_explanationToIssue),
        if (trustExplanations.isNotEmpty)
          _RawParagraph(
              '\nThese issues are present but do not affect the score, because they may not originate in your package:\n'),
        ...trustExplanations.map(_explanationToIssue),
      ];

      final officialTags = tags.where(tagNames.containsKey).toList();
      final status = statusFromCount(officialTags.length);
      final score = {
        ReportStatus.failed: 0,
        ReportStatus.partial: 10,
        ReportStatus.passed: 20
      }[status];

      final platforms = platformList(tags, tagNames);
      final description = 'Supports ${officialTags.length} of '
          '${tagNames.length} possible platforms ($platforms)';
      return _Subsection(description, paragraphs, score, 20, status);
    }

    if (flutterPackage) {
      tagger.flutterPlatformTags(tags, explanations, trustDeclarations: true);
      final tagNames = const {
        'platform:ios': 'iOS',
        'platform:android': 'Android',
        'platform:web': 'Web',
      };
      subsection = scorePlatforms(
        tagNames,
        (count) => count <= 1
            ? ReportStatus.failed
            : (count == 2 ? ReportStatus.partial : ReportStatus.passed),
        tags,
        explanations,
      );
    } else {
      tagger.runtimeTags(tags, explanations);

      final tagNames = const {
        'runtime:native-jit': 'native',
        'runtime:web': 'js',
      };

      // We don't want the native-aut runtime to be explained here.
      explanations.removeWhere(
          (explanation) => explanation.tag == Runtime.nativeAot.tag);

      subsection = scorePlatforms(
        tagNames,
        (count) => count == 0
            ? ReportStatus.failed
            : (count == 1 ? ReportStatus.partial : ReportStatus.passed),
        tags,
        explanations,
      );
    }
  } else {
    subsection = _Subsection(
      'Supports 0 of 2 possible platforms (native, js)',
      [
        _Issue('Package resolution failed. Could not determine platforms.',
            suggestion: 'Run `pub get` for more information.')
      ],
      0,
      20,
      ReportStatus.failed,
    );
  }

  return _makeSection(
      id: ReportSectionId.platform,
      title: 'Support multiple platforms',
      maxPoints: 20,
      basePath: packageDir,
      subsections: [subsection]);
}

ReportSection _makeSection(
    {@required String id,
    @required String title,
    @required int maxPoints,
    @required List<_Subsection> subsections,
    @required String basePath,
    int maxIssues = 2}) {
  return ReportSection(
      id: id,
      title: title,
      grantedPoints:
          subsections.fold(0, (p, subsection) => p + subsection.grantedPoints),
      maxPoints: maxPoints,
      summary:
          _makeSummary(subsections, basePath: basePath, maxIssues: maxIssues),
      status: summarizeStatuses(subsections.map((s) => s.status)));
}

/// Loads [SourceSpan] on-demand.
typedef SourceSpanFn = SourceSpan Function();

abstract class _Paragraph {
  String markdown({@required String basePath});
}

class _RawParagraph implements _Paragraph {
  final String _markdown;

  _RawParagraph(this._markdown);

  @override
  String markdown({@required basePath}) => _markdown;
}

_Issue _unsupportedDartSdk(PackageContext context,
    {String command, String suggestion}) {
  final msg = StringBuffer(
      "Sdk constraint doesn't support current Dart version ${context.currentSdkVersion}.");
  if (command != null) {
    msg.write(' Cannot run `$command`.');
  }
  return _Issue(
    msg.toString(),
    span: _tryGetSpanFromYamlMap(context.pubspec.environment, 'sdk'),
    suggestion: suggestion,
  );
}

/// A single issue found by the analysis.
///
/// This is not part of the external data-model, but used for gathering
/// sub-problems for making a [ReportSection] summary.
class _Issue implements _Paragraph {
  /// Markdown description of the issue.
  final String description;

  /// Source location of the problem in [span].
  ///
  /// If we know nothing more than the file the problem occurs in (no specific
  /// line numbers), that file path should be included in [description].
  final SourceSpan span;

  /// Similar to [span], but with deferred loading from the filesystem.
  ///
  /// [SourceSpanFn] may return `null`, if when loaded the offset is invalid.
  final SourceSpanFn spanFn;

  /// Can be used for giving a potential solution of the issue, and
  /// also for a command to reproduce locally.
  final String suggestion;

  _Issue(this.description, {this.span, this.spanFn, this.suggestion});

  @override
  String markdown({@required String basePath}) {
    final span = this.span ?? (spanFn == null ? null : spanFn());
    if (suggestion == null && span == null) {
      return '* $description';
    }
    return [
      '<details>',
      '<summary>',
      description,
      '</summary>',
      '', // This empty line will make the span render its markdown.
      if (span != null) span.markdown(basePath: basePath),
      if (suggestion != null) suggestion,
      '</details>',
    ].join('\n');
  }
}

extension on SourceSpan {
  /// An attempt to render [SourceSpan]s in a markdown-friendly way.
  ///
  /// The file path will be relative to [basePath].
  String markdown({@required String basePath}) {
    assert(sourceUrl != null);
    final path = p.relative(sourceUrl.path, from: basePath);
    return '`$path:${start.line + 1}:${start.column + 1}`\n\n'
        '```\n${highlight()}\n```\n';
  }
}

class _Subsection {
  final List<_Paragraph> issues;
  final String description;
  final int grantedPoints;
  final int maxPoints;
  final String bodyPrefix;

  final ReportStatus status;

  _Subsection(
    this.description,
    this.issues,
    this.grantedPoints,
    this.maxPoints,
    this.status, {
    this.bodyPrefix = '',
  });
}

/// Given an introduction and a list of issues, formats the summary of a
/// section.
String _makeSummary(List<_Subsection> subsections,
    {String introduction, @required String basePath, int maxIssues = 2}) {
  return [
    if (introduction != null) introduction,
    ...subsections.map((subsection) {
      final issuesMarkdown =
          subsection.issues.map((e) => e.markdown(basePath: basePath));
      final statusMarker = reportStatusMarker(subsection.status);
      return [
        '### $statusMarker ${subsection.grantedPoints}/${subsection.maxPoints} points: ${subsection.description}\n',
        if (subsection.bodyPrefix != null && subsection.bodyPrefix.isNotEmpty)
          '${subsection.bodyPrefix}',
        if (subsection.issues.isNotEmpty &&
            subsection.issues.length <= maxIssues)
          issuesMarkdown.join('\n'),
        if (subsection.issues.length > maxIssues) ...[
          'Found ${subsection.issues.length} issues. Showing the first $maxIssues:\n',
          issuesMarkdown.take(maxIssues).join('\n'),
        ],
      ].join('\n');
    }),
  ].join('\n\n');
}

String reportStatusMarker(ReportStatus status) => const {
      ReportStatus.passed: '[*]',
      ReportStatus.failed: '[x]',
      ReportStatus.partial: '[~]'
    }[status];

/// Renders a summary block for sections that can have only a single issue.
String renderSimpleSectionSummary({
  @required String title,
  @required String description,
  @required int grantedPoints,
  @required int maxPoints,
}) {
  return _makeSummary([
    _Subsection(
      title,
      [if (description != null) _Issue(description)],
      grantedPoints,
      maxPoints,
      maxPoints == grantedPoints
          ? ReportStatus.passed
          : grantedPoints == 0
              ? ReportStatus.failed
              : ReportStatus.partial,
    )
  ], basePath: null);
}
