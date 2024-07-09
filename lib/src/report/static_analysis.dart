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
import '../tool/run_constrained.dart';
import '../utils.dart';
import '_common.dart';

Future<ReportSection> staticAnalysis(PackageContext context) async {
  final packageDir = context.packageDir;
  final analysisResult = await _analyzePackage(context);

  final errors = analysisResult.errors;
  final warnings = analysisResult.warnings;
  final lints = analysisResult.lints;

  // Only try to run dart format if there where no errors.
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

  // 30 points: static analysis has 0 errors
  // 40 points: static analysis has 0 errors, warnings
  // 50 points: static analysis has 0 errors, warnings, lints
  var grantedPoints = 0;
  if (errors.isEmpty) {
    grantedPoints = 30;
    if (warnings.isEmpty) {
      grantedPoints = 40;
      if (lints.isEmpty && formattingIssues.isEmpty) {
        grantedPoints = 50;
      }
    }
  }
  return makeSection(
    id: ReportSectionId.analysis,
    title: 'Pass static analysis',
    maxPoints: 50,
    subsections: [
      Subsection(
        'code has no errors, warnings, lints, or formatting issues',
        [...errors, ...warnings, ...lints, ...formattingIssues],
        grantedPoints,
        50,
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
          'To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and '
          'run `${context.usesFlutter ? 'flutter analyze' : 'dart analyze'} ${codeProblem.file}`',
      spanFn: () => sourceSpanFromFile(
        path: p.join(context.packageDir, codeProblem.file),
        line: codeProblem.line,
        col: codeProblem.col,
        length: codeProblem.length,
      ),
    );
  }

  final dirs = await listFocusDirs(context.packageDir);

  try {
    final resolveErrorMessage = await context.resolveErrorMessage;
    if (resolveErrorMessage != null) {
      return _AnalysisResult(
        [Issue(resolveErrorMessage)],
        [],
        [],
        context.usesFlutter ? 'flutter pub get' : 'dart pub get',
      );
    }
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

FileSpan? sourceSpanFromFile({
  required String path,
  required int line,
  required int col,
  required int length,
}) {
  final sourceText = File(path).readAsStringSync();
  final sourceFile = SourceFile.fromString(sourceText, url: path);
  try {
    // SourceSpans are 0-based, so we subtract 1 from line and column.
    var startOffset = sourceFile.getOffset(line - 1, col - 1);

    // making sure that we don't start on CR line terminator
    // TODO: Remove this after https://github.com/dart-lang/source_span/issues/79 gets fixed.
    while (startOffset < sourceText.length &&
        sourceText.codeUnitAt(startOffset) == 13) {
      startOffset++;
    }
    // Limit the maximum length of the source span.
    var newLength = math.min(length, maxSourceSpanLength);
    newLength = math.min(newLength, sourceText.length - startOffset);
    // making sure that we don't end on CR line terminator
    // TODO: Remove this after https://github.com/dart-lang/source_span/issues/79 gets fixed.
    while (newLength > 0 &&
        sourceText.codeUnitAt(startOffset + newLength - 1) == 13) {
      newLength--;
    }
    if (newLength <= 0) {
      // Note: this may happen if the span is entirely CR line terminators.
      return null;
    }
    return sourceFile.span(startOffset, startOffset + newLength);
    // ignore: avoid_catching_errors
  } on RangeError {
    // Note: This happens if the file contains CR as line terminators.
    // If the range is invalid, then we just return null.
    return null;
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
              suggestion: 'To format your files run: `dart format .`',
            ))
        .toList();
  } on ToolException catch (e) {
    return [
      Issue('Running `dart format` failed:\n```\n${e.message}```'),
    ];
  } catch (e, stack) {
    log.severe('`dart format` failed.\n$e', e, stack);
    return [
      Issue('Running `dart format` failed.'),
    ];
  }
}
