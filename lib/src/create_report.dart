// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:pana/pana.dart';
import 'package:pana/src/tag_detection.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart'
    show GitDependency, HostedDependency;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';
import 'package:logging/logging.dart';

import '../models.dart';
import 'markdown_content.dart';
import 'pubspec.dart';

const _publisherDoc = 'https://dart.dev/tools/pub/verified-publishers';

const _pluginDocsUrl =
    'https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin';

final currentSdkVersion = Version.parse(Platform.version.split(' ').first);
final _log = Logger('pana.create_report');

/// We currently don't have flutter installed on travis. So we emulate having
/// no Flutter installed when generating golden files.
// TODO(sigurdm): try to get Flutter on travis.
var isRunningEnd2EndTest = false;

Future<Report> createReport(
  InspectOptions options,
  String packageDir,
  ToolEnvironment toolEnvironment,
) async {
  Pubspec pubspec;
  try {
    pubspec = Pubspec.parseFromDir(packageDir);
  } on Exception catch (e) {
    return Report(sections: [
      ReportSection(
          grantedPoints: 0,
          maxPoints: 100,
          title: 'Failed to parse the pubspec',
          summary: e.toString())
    ]);
  }

  return Report(sections: [
    await _followsTemplate(options, packageDir, pubspec),
    await _hasDocumentation(packageDir, pubspec),
    await _multiPlatform(packageDir, pubspec),
    await _staticAnalysis(
      packageDir,
      toolEnvironment,
      usesFlutter: pubspec.usesFlutter,
    ),
    await _trustworthyDependency(packageDir, pubspec, toolEnvironment),
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
      _Issue('Found example at: $examplePath')
  ];

  final points = examplePath == null ? 0 : 10;
  final status = examplePath == null ? _Status.bad : _Status.good;
  return ReportSection(
    title: documentationSectionTitle,
    grantedPoints: points,
    maxPoints: 10,
    summary: _makeSummary(
        [_Subsection('Package has an example', issues, points, 10, status)],
        basePath: null),
  );
}

Future<ReportSection> _staticAnalysis(
  String packageDir,
  ToolEnvironment toolEnvironment, {
  @required bool usesFlutter,
}) async {
  final analysisResult = await _analyzePackage(packageDir, toolEnvironment,
      usesFlutter: usesFlutter);

  final errors = analysisResult.errors;
  final warnings = analysisResult.warnings;
  final lints = analysisResult.lints;

  // Only try to run dartfmt if there where no errors.
  final formattingIssues = errors.isEmpty
      ? await _formatPackage(packageDir, toolEnvironment,
          usesFlutter: usesFlutter)
      : <_Issue>[];

  final status = (errors.isEmpty && warnings.isEmpty)
      ? (formattingIssues.isEmpty && lints.isEmpty
          ? _Status.good
          : _Status.soso)
      : _Status.bad;
  final grantedPoints = (errors.isEmpty && warnings.isEmpty)
      ? (formattingIssues.isEmpty && lints.isEmpty ? 20 : 10)
      : 0;

  return ReportSection(
    title: 'Code follows recommended code style',
    grantedPoints: grantedPoints,
    maxPoints: 20,
    summary: _makeSummary(
      [
        _Subsection(
          'code has no errors, warnings, lints, or formatting issues',
          [...errors, ...warnings, ...lints, ...formattingIssues],
          grantedPoints,
          20,
          status,
        )
      ],
      basePath: packageDir,
    ),
  );
}

Future<_AnalysisResult> _analyzePackage(
  String packagePath,
  ToolEnvironment toolEnvironment, {
  @required bool usesFlutter,
}) async {
  _Issue issueFromCodeProblem(CodeProblem codeProblem) {
    return _Issue(
      '${codeProblem.severity}: ${codeProblem.description}',
      // TODO(sigurdm) We need to inject pedantic somehow...
      suggestion: 'To reproduce run `dart analyze ${codeProblem.file}`',
      spanFn: () {
        final sourceFile = SourceFile.fromString(
            File(p.join(packagePath, codeProblem.file)).readAsStringSync(),
            url: p.join(packagePath, codeProblem.file));
        // SourceSpans are 0-based, so we subtract 1 from line and column.
        final startOffset =
            sourceFile.getOffset(codeProblem.line - 1, codeProblem.col - 1);
        return sourceFile.span(startOffset, startOffset + codeProblem.length);
      },
    );
  }

  final dirs = await listFocusDirs(packagePath);

  try {
    final output = await toolEnvironment.runAnalyzer(
      packagePath,
      dirs,
      usesFlutter,
      inspectOptions: InspectOptions(),
    );
    final list = LineSplitter.split(output)
        .map((s) => parseCodeProblem(s, projectDir: packagePath))
        .where((e) => e != null)
        .toSet()
        .toList();
    list.sort();

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
    _log.severe('`dartfmt` failed.\n$e', e, stack);
    return [
      _Issue('Running `dartfmt` failed.'),
    ];
  }
}

Future<ReportSection> _followsTemplate(
    InspectOptions options, String packageDir, Pubspec pubspec) async {
  final urlChecker = UrlChecker();

  Future<List<_Issue>> findUrlIssues(
    String key,
    String name, {
    bool isRequired = false,
  }) async {
    final url = pubspec.originalYaml[key] as String;
    final issues = <_Issue>[];

    if (url == null || url.isEmpty) {
      if (isRequired) {
        issues.add(
          _Issue("`pubspec.yaml` doesn't have a `$key` entry."),
        );
      }
      return issues;
    }

    final status = await urlChecker.checkStatus(
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
            'Links in $filename should be well formed '
            'Unable to parse $count image links$s.',
            span: first.span));
      }
      if (checked.insecure.isNotEmpty) {
        final count = checked.insecure.length;
        final first = checked.insecure.first;
        final sAre = count == 1 ? ' is' : 's are';
        issues.add(_Issue(
            'Links in $filename should be secure. $count $linkType$sAre insecure.',
            suggestion: 'Use `https` URLs instead.',
            span: first.span));
      }
    }

    await findLinkIssues(analysis.links, 'link');
    await findLinkIssues(analysis.images, 'image link');

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

    issues.addAll(findFileSizeIssues(File(p.join(packageDir, 'pubspec.yaml')),
        limitInKB: 32));

    final status = issues.isEmpty ? _Status.good : _Status.bad;
    final points = issues.isEmpty ? 10 : 0;
    return _Subsection(
        'Provide a valid pubspec.yaml', issues, points, 10, status);
  }

  Future<_Subsection> checkAsset(
      String filename, String missingSuggestion) async {
    final fullPath = p.join(packageDir, filename);
    final file = File(fullPath);
    final issues = <_Issue>[];

    if (!file.existsSync()) {
      issues.add(
        _Issue('No $filename found.', suggestion: missingSuggestion),
      );
    } else {
      issues.addAll(
          findFileSizeIssues(file, missingSuggestion: missingSuggestion));
      issues.addAll(await findMarkdownIssues(file));
    }
    final status = issues.isEmpty ? _Status.good : _Status.bad;
    final points = issues.isEmpty ? 5 : 0;
    return _Subsection('Provide a valid $filename', issues, points, 5, status);
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

  return ReportSection(
      title: 'Packaging conventions',
      maxPoints: 20,
      grantedPoints: pubspecSection.grantedPoints +
          readmeSubsection.grantedPoints +
          changelogSubsection.grantedPoints,
      summary: _makeSummary(
          [pubspecSection, readmeSubsection, changelogSubsection],
          basePath: packageDir, maxIssues: 10));
}

SourceSpan _tryGetSpanFromYamlMap(Map map, String key) {
  if (map is YamlMap) {
    return map.nodes[key]?.span;
  }
  return null;
}

Future<ReportSection> _trustworthyDependency(
  String packageDir,
  Pubspec pubspec,
  ToolEnvironment toolEnvironment,
) async {
  Future<_Subsection> dependencies() async {
    final issues = <_Issue>[];
    if (pubspec.dartSdkConstraint != null &&
        pubspec.dartSdkConstraint.allows(currentSdkVersion)) {
      try {
        final outdated = await toolEnvironment.runPubOutdated(packageDir,
            args: ['--json', '--no-dev-dependencies']);
        for (final package in outdated['packages'] as List) {
          if (package is Map) {
            final name = package['package'];
            final latest = package['latest'];
            if (name is String && latest is String) {
              final latestVersion = Version.parse(latest);
              final dependency = pubspec.dependencies[name];
              if (dependency is HostedDependency &&
                  !dependency.version.allows(latestVersion)) {
                issues.add(_Issue(
                    'The constraint ${dependency.version} on $name does not support the latest published version $latestVersion',
                    span:
                        _tryGetSpanFromYamlMap(pubspec.dependencies, 'name')));
              }
            }
          }
        }
      } on ToolException catch (e) {
        issues.add(_Issue('Could not run pub outdated: ${e.message}'));
      }
    } else {
      issues.add(_Issue(
          "Sdk constraint doesn't support current Dart version $currentSdkVersion."
          ' Cannot run `pub outdated`.',
          span: _tryGetSpanFromYamlMap(pubspec.environment, 'sdk')));
    }
    final status = issues.isEmpty ? _Status.good : _Status.bad;
    final points = issues.isEmpty ? 10 : 0;

    return _Subsection(
      'All of the package dependencies are supported in the latest version',
      issues,
      points,
      10,
      status,
    );
  }

  Future<_Subsection> sdkSupport() async {
    final issues = <_Issue>[];
    final sdkConstraint = pubspec.dartSdkConstraint;
    final allowsCurrentSdk = sdkConstraint?.allows(currentSdkVersion) ?? false;
    if (sdkConstraint == null) {
      issues.add(_Issue('Pubspec.yaml does not have an sdk version constraint.',
          suggestion: 'Try adding an sdk constraint to your pubspec.yaml'));
    } else if (!allowsCurrentSdk) {
      issues.add(_Issue(
          'The current sdk constraint does not allow the latest stable Dart ($currentSdkVersion)',
          span: _tryGetSpanFromYamlMap(pubspec.environment, 'sdk'),
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
    final status = issues.isEmpty ? _Status.good : _Status.bad;
    final points = issues.isEmpty ? 10 : 0;
    return _Subsection(
      'Package supports latest stable Dart and Flutter SDKs',
      issues,
      points,
      10,
      status,
    );
  }

  Future<_Subsection> publisher() async {
    final issues = <_Issue>[];
    String publisher;

    try {
      publisher = json.decode(await read(
              'https://pub.dev/api/packages/${Uri.encodeComponent(pubspec.name)}/publisher'))[
          'publisherId'] as String;
    } on ClientException catch (e) {
      issues.add(_Issue(
        'Could not retrieve publisher information. Has this package been published before? ($e)',
      ));
    }

    if (publisher == null) {
      issues.add(_Issue('Package is not published under a verified publisher.',
          suggestion: 'See $_publisherDoc for more information.'));
    }
    final status = issues.isEmpty ? _Status.good : _Status.bad;
    final points = issues.isEmpty ? 10 : 0;
    return _Subsection(
      'Package is published using a verified publisher',
      issues,
      points,
      10,
      status,
    );
  }

  final dependencySection = await dependencies();
  final sdkSection = await sdkSupport();
  final publisherSection = await publisher();

  return ReportSection(
      title: 'Package is a good, trustworthy dependency',
      grantedPoints: dependencySection.grantedPoints +
          sdkSection.grantedPoints +
          publisherSection.grantedPoints,
      maxPoints: 30,
      summary: _makeSummary([dependencySection, sdkSection, publisherSection],
          basePath: packageDir));
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

    final flutterPackage = pubspec.hasFlutterKey;

    _Issue explanationToIssue(Explanation explanation) =>
        _Issue(explanation.finding, suggestion: explanation.explanation);

    String platformList(List<String> tags, Map<String, String> tagNames) {
      return tagNames.entries.map((entry) {
        if (tags.contains(entry.key)) {
          return '**${entry.value}**';
        } else {
          return entry.value;
        }
      }).join(', ');
    }

    if (flutterPackage) {
      tagger.flutterPlatformTags(tags, explanations, trustDeclarations: false);
      final issues = explanations.map(explanationToIssue).toList();
      final tagNames = const {
        'platform:ios': 'iOs',
        'platform:android': 'Android',
        'platform:web': 'Web',
      };

      final officialTags = tags.where(tagNames.containsKey).toList();
      final platforms = platformList(tags, tagNames);
      if (officialTags.length <= 1) {
        subsection = _Subsection(
            'Supports 0 of 3 possible platforms ($platforms)',
            issues,
            0,
            20,
            _Status.bad);
      } else if (officialTags.length == 2) {
        subsection = _Subsection(
            'Supports 2 of 3 possible platforms ($platforms)',
            issues,
            10,
            20,
            _Status.soso);
      } else {
        subsection = _Subsection(
            'Supports 3 of 3 possible platforms ($platforms)',
            issues,
            20,
            20,
            _Status.good);
      }
    } else {
      tagger.runtimeTags(tags, explanations);
      final issues = explanations.map(explanationToIssue).toList();

      final tagNames = const {
        'runtime:native-aot': 'native',
        'runtime:web': 'js',
      };
      final officialTags = tags.where(tagNames.containsKey).toList();

      final platforms = platformList(tags, tagNames);
      if (officialTags.isEmpty) {
        subsection = _Subsection(
            'Supports 0 of 2 possible platforms ($platforms)',
            issues,
            0,
            20,
            _Status.bad);
      } else if (officialTags.length == 1) {
        subsection = _Subsection(
            'Supports 1 of 2 possible platforms ($platforms)',
            issues,
            10,
            20,
            _Status.soso);
      } else {
        subsection = _Subsection(
            'Supports 2 of 2 possible platforms ($platforms)',
            issues,
            20,
            20,
            _Status.good);
      }
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
      _Status.bad,
    );
  }

  return ReportSection(
    title: 'Package is multi-platform',
    maxPoints: 20,
    grantedPoints: subsection.grantedPoints,
    summary: _makeSummary(
      [subsection],
      basePath: packageDir,
      maxIssues:
          100, // Tagging produces a bounded number of issues. Better display them all.
    ),
  );
}

/// Loads [SourceSpan] on-demand.
typedef SourceSpanFn = SourceSpan Function();

/// A single issue found by the analysis.
///
/// This is not part of the external data-model, but used for gathering
/// sub-problems for making a [ReportSection] summary.
class _Issue {
  /// Markdown description of the issue.
  final String description;

  /// Source location of the problem in [span].
  ///
  /// If we know nothing more than the file the problem occurs in (no specific
  /// line numbers), that file path should be included in [description].
  final SourceSpan span;

  /// Similar to [span], but with deferred loading from the filesystem.
  final SourceSpanFn spanFn;

  /// Can be used for giving a potential solution of the issue, and
  /// also for a command to reproduce locally.
  final String suggestion;

  _Issue(this.description, {this.span, this.spanFn, this.suggestion});

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
      if (span != null)
        span.markdown(basePath: basePath),
      if (suggestion != null)
        suggestion,
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
  final List<_Issue> issues;
  final String description;
  final int grantedPoints;
  final int maxPoints;

  final _Status status;

  _Subsection(
    this.description,
    this.issues,
    this.grantedPoints,
    this.maxPoints,
    this.status,
  );
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
      final statusMarker = _statusMarker(subsection.status);
      return [
        '### $statusMarker ${subsection.grantedPoints}/${subsection.maxPoints} points: ${subsection.description}\n',
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

String _statusMarker(_Status status) => const {
      _Status.good: '[*]',
      _Status.bad: '[x]',
      _Status.soso: '[~]'
    }[status];

enum _Status {
  good,
  bad,
  soso,
}

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
          ? _Status.good
          : grantedPoints == 0 ? _Status.bad : _Status.soso,
    )
  ], basePath: null);
}
