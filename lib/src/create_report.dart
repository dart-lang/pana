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
10 points: code has no errors and warnings.
20 points: code has no errors, warnings or lints, and is formatted according to dartfmt''',
        [...errors, ...warnings, ...lints, ...formattingIssues],
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
      codeProblem.description,
      suggestion: 'To reproduce run `dartanalyzer ${codeProblem.file}`',
      /*XXX Pass correct options*/
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
        ...issuesMarkdown.take(2),
      ],
    ],
  ].join('\n');
}
