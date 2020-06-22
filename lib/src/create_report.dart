// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/pana.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../models.dart';
import 'markdown_content.dart';
import 'pubspec.dart';

Future<Report> createReport(
    String packageDir, ToolEnvironment toolEnvironment) async {
  Pubspec pubspec;
  try {
    pubspec = Pubspec.parseFromDir(packageDir);
  } on Exception catch (e) {
    throw Exception('Cannot not create report without a pubspec.yaml: $e');
  }

  return Report(sections: [
    _supportsDart2(packageDir, pubspec),
    await _followsTemplate(packageDir, pubspec),
    await _staticAnalysis(
      packageDir,
      toolEnvironment,
      usesFlutter: pubspec.usesFlutter,
    ),
    // TODO(sigurdm):Implement rest of sections.
  ]);
}

ReportSection _supportsDart2(String packageDir, Pubspec pubspec) {
  final supportsDart2 = pubspec.sdkConstraintStatus.isDart2Compatible;
  final issues = <_Issue>[];

  if (!supportsDart2) {
    final environment = pubspec.environment;
    SourceSpan span;
    if (environment is YamlMap) {
      final sdk = environment.nodes['sdk'];
      if (sdk is YamlNode) {
        span = sdk.span;
      }
    }

    final sdk = environment == null ? false : environment['sdk'];

    issues.add(
      sdk is String
          ? _Issue(
              'The current sdk constraint $sdk does not allow any Dart 2 versions.',
              span: span,
            )
          : _Issue(
              '`pubspec.yaml` has no sdk constraint. '
              'Dart 2 support requires an sdk-constraint.',
              suggestion: '''
Add an sdk-constraint to `pubspec.yaml`. For example:
```
environment:
  sdk: '>=2.8.0 <3.0.0'
```
'''),
    );
  }

  return ReportSection(
      title: 'Package supports Dart 2',
      maxPoints: 20,
      grantedPoints: supportsDart2 ? 20 : 0,
      summary: _makeSummary(
          'Package gets 20 points if its Dart sdk constraint allows Dart 2.',
          issues,
          basePath: packageDir));
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

  return ReportSection(
    title: 'Code follows recommended code style',
    maxPoints: 20,
    grantedPoints: (errors.isEmpty && warnings.isEmpty)
        ? (formattingIssues.isEmpty && lints.isEmpty ? 20 : 10)
        : 0,
    summary: _makeSummary('''
*10 points:* code has no errors and warnings.

*20 points:* code has no errors, warnings or lints, and is formatted according to dartfmt.
''', [...errors, ...warnings, ...lints, ...formattingIssues],
        basePath: packageDir),
  );
}

Future<_AnalysisResult> _analyzePackage(
  String packagePath,
  ToolEnvironment toolEnvironment, {
  @required bool usesFlutter,
}) async {
  _Issue issueFromCodeProblem(CodeProblem codeProblem) {
    final sourceFile = SourceFile.fromString(
        File(p.join(packagePath, codeProblem.file)).readAsStringSync(),
        url: codeProblem.file);
    // SourceSpans are 0-based, so we subtract 1 from line and column.
    final startOffset =
        sourceFile.getOffset(codeProblem.line - 1, codeProblem.col - 1);
    return _Issue(
      '${codeProblem.severity}: ${codeProblem.description}',
      // TODO(sigurdm) We need to inject pedantic somehow...
      suggestion: 'To reproduce run `dart analyze ${codeProblem.file}`',
      span: sourceFile.span(startOffset, startOffset + codeProblem.length),
    );
  }

  final dirs = await listFocusDirs(packagePath);

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
  final unformattedFiles = await toolEnvironment.filesNeedingFormat(
    packageDir,
    usesFlutter,
  );
  return unformattedFiles
      .map((f) => _Issue('$f is not formatted according to dartfmt',
          suggestion: 'To format your files run: `dartfmt -w .`'))
      .toList();
}

Future<ReportSection> _followsTemplate(
    String packageDir, Pubspec pubspec) async {
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

  // TODO(sigurdm): What do we want to check here?
  final validPubspec = true;

  Future<List<_Issue>> checkAsset(
      String filename, String missingSuggestion) async {
    List<_Issue> findFileSizeIssues(File file, {int limitInKB = 128}) {
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

    final fullPath = p.join(packageDir, filename);
    final file = File(fullPath);
    final issues = <_Issue>[];

    if (!file.existsSync()) {
      issues.add(
        _Issue('No $filename found.', suggestion: missingSuggestion),
      );
    } else {
      issues.addAll(findFileSizeIssues(file));
      issues.addAll(await findMarkdownIssues(
        file,
      ));
    }
    return issues;
  }

  final readmeIssues = await checkAsset(
    'README.md',
    'The `README.md` file should inform others about your project, what it does, and how they can use it. '
        'See: the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/README.md) generated by `stagehand`.',
  );
  final changelogIssues = await checkAsset(
    'CHANGELOG.md',
    'Changelog entries help developers follow the progress of your package. '
        'See the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/CHANGELOG.md) generated by `stagehand`.',
  );

  return ReportSection(
      title: 'Packaging conventions',
      maxPoints: 20,
      grantedPoints: (validPubspec ? 10 : 0) +
          (readmeIssues.isEmpty ? 5 : 0) +
          (changelogIssues.isEmpty ? 5 : 0),
      summary: _makeSummary(
          'Package gets 10 points for a valid pubspec.yaml and 5 points for each of README.md and CHANGELOG.md.',
          [...readmeIssues, ...changelogIssues],
          basePath: packageDir));
}

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

  /// Can be used for giving a potential solution of the issue, and
  /// also for a command to reproduce locally.
  final String suggestion;

  _Issue(this.description, {this.span, this.suggestion});

  String markdown({@required String basePath}) {
    return [
      description,
      if (span != null) span.markdown(basePath: basePath),
      if (suggestion != null) suggestion
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

/// Given an introduction and a list of issues, formats the summary of a
/// section.
String _makeSummary(String introduction, List<_Issue> issues,
    {@required String basePath}) {
  final issuesMarkdown = issues.map((e) => e.markdown(basePath: basePath));
  return [
    introduction,
    if (issues.isNotEmpty) ...[
      '',
      if (issues.length <= 2)
        ...issuesMarkdown
      else ...[
        'Found ${issues.length} issues. Showing the first two:',
        '',
        ...issuesMarkdown.take(2),
      ],
    ],
  ].join('\n');
}
