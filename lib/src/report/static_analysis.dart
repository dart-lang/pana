// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../internal_model.dart';
import '../logging.dart';
import '../model.dart';
import '../package_context.dart';
import '../sdk_env.dart';
import '../utils.dart';
import '_common.dart';

Future<ReportSection> staticAnalysis(PackageContext context) async {
  final packageDir = context.packageDir;
  final analysisResult = await _analyzePackage(context);

  final errors = analysisResult.errors;
  final warnings = analysisResult.warnings;
  final lints = analysisResult.lints;

  // Only try to run dartfmt if there where no errors.
  final formattingIssues = errors.isEmpty
      ? await _formatPackage(
          packageDir,
          context.toolEnvironment,
          usesFlutter: context.usesFlutter,
          lineLength: context.options.lineLength,
        )
      : <Issue>[];

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
  return makeSection(
    id: ReportSectionId.analysis,
    title: 'Pass static analysis',
    maxPoints: 30,
    subsections: [
      Subsection(
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
  Issue issueFromCodeProblem(CodeProblem codeProblem) {
    return Issue(
      '${codeProblem.severity}: ${codeProblem.description}',
      suggestion:
          'To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and '
          'run `${context.usesFlutter ? 'flutter analyze' : 'dart analyze'} ${codeProblem.file}`',
      spanFn: () {
        final sourceFile = SourceFile.fromString(
            File(p.join(context.packageDir, codeProblem.file))
                .readAsStringSync(),
            url: p.join(context.packageDir, codeProblem.file));
        try {
          // SourceSpans are 0-based, so we subtract 1 from line and column.
          final startOffset =
              sourceFile.getOffset(codeProblem.line - 1, codeProblem.col - 1);
          // Limit the maximum length of the source span.
          final length = math.min(codeProblem.length, maxSourceSpanLength);
          return sourceFile.span(startOffset, startOffset + length);
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
        'dart analyze ${dirs.join(' ')}');
  } on ToolException catch (e) {
    return _AnalysisResult(
      [
        Issue('Failed to run `dart analyze`:\n```\n${e.message}\n```\n'),
      ],
      [],
      [],
      'dart analyze ${dirs.join(' ')}',
    );
  }
}

class _AnalysisResult {
  final List<Issue> errors;
  final List<Issue> warnings;
  final List<Issue> lints;
  final String reproductionCommand;

  _AnalysisResult(
      this.errors, this.warnings, this.lints, this.reproductionCommand);
}

Future<List<Issue>> _formatPackage(
  String packageDir,
  ToolEnvironment toolEnvironment, {
  required bool usesFlutter,
  int? lineLength,
}) async {
  try {
    final unformattedFiles = await toolEnvironment.filesNeedingFormat(
      packageDir,
      usesFlutter,
      lineLength: lineLength,
    );
    return unformattedFiles
        .map((f) => Issue(
              '$f doesn\'t match the Dart formatter.',
              suggestion: usesFlutter
                  ? 'To format your files run: `flutter format .`'
                  : 'To format your files run: `dart format .`',
            ))
        .toList();
  } on ToolException catch (e) {
    return [
      Issue('Running `dartfmt` failed:\n```\n${e.message}```'),
    ];
  } catch (e, stack) {
    log.severe('`dartfmt` failed.\n$e', e, stack);
    return [
      Issue('Running `dartfmt` failed.'),
    ];
  }
}
