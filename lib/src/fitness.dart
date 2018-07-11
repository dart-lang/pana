// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.health;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'messages.dart' as messages;
import 'model.dart';
import 'pubspec.dart';

class FitnessResult {
  final Fitness fitness;
  final List<Suggestion> suggestions;

  FitnessResult(this.fitness, this.suggestions);
}

Future<FitnessResult> calcFitness(
    String pkgDir,
    Pubspec pubspec,
    String dartFile,
    bool isFormatted,
    List<CodeProblem> fileAnalyzerItems,
    List<String> directLibs,
    DartPlatform platform) async {
  // statement count estimated by:
  // - counting the non-comment ';' characters
  // - counting the non-empty lines
  // - assumed average line length
  var content = await new File(p.join(pkgDir, dartFile)).readAsString();
  content = content
      .replaceAll(_blockCommentRegExp, '')
      .replaceAll(_lineCommentRegExp, '');
  final semiColonCount = content.replaceAll(_antiSemiColonRegExp, '').length;
  final nonEmptyLineCount =
      content.split('\n').where((line) => line.trim().isNotEmpty).length;
  final statementEstimate = content.length ~/ 40;
  final statementCount =
      (semiColonCount + nonEmptyLineCount + statementEstimate) ~/ 3;

  // code magnitude is estimated by the imported lib count and statement count
  final magnitude =
      max(1.0, ((directLibs?.length ?? 0) + statementCount).toDouble());

  // major issues are penalized in the percent of the total
  // minor issues are penalized in a fixed amount
  final errorPoints = max(10.0, magnitude * 0.20); // 20%
  final warnPoints = max(4.0, magnitude * 0.05); // 5%
  final hintPoints = 1.0;

  final suggestions = <Suggestion>[];
  var shortcoming = 0.0;

  if (platform != null && platform.hasConflict) {
    shortcoming += errorPoints;
    final components = platform?.components?.map((s) => '`$s`')?.join(', ');
    var description =
        'Make sure that the imported libraries are not in conflict.';
    if (components != null) {
      description += ' Detected components: $components.';
    }
    if (platform.reason != null && platform.reason.isNotEmpty) {
      description += ' ${platform.reason}';
    }
    suggestions.add(new Suggestion.error(
      SuggestionCode.platformConflictInFile,
      'Fix platform conflict in `$dartFile`.',
      description,
      file: dartFile,
      penalty: new Penalty(fraction: 2000, amount: errorPoints.ceil()),
    ));
  }

  if (isFormatted == null || !isFormatted) {
    shortcoming += hintPoints;
    suggestions.add(new Suggestion.hint(
      SuggestionCode.dartfmtWarning,
      'Format `$dartFile`.',
      messages.runDartfmtToFormatFile(pubspec.usesFlutter, dartFile),
      file: dartFile,
      penalty: new Penalty(amount: hintPoints.ceil()),
    ));
  }

  if (fileAnalyzerItems != null && fileAnalyzerItems.isNotEmpty) {
    fileAnalyzerItems.sort((a, b) => a.severityCompareTo(b));
    final errorCount = fileAnalyzerItems.where((c) => c.isError).length;
    final warningCount = fileAnalyzerItems.where((c) => c.isWarning).length;
    final hintCount = fileAnalyzerItems.where((c) => c.isInfo).length;
    final maxLevel = errorCount > 0
        ? SuggestionLevel.error
        : (warningCount > 0 ? SuggestionLevel.warning : SuggestionLevel.hint);

    final failedWith =
        maxLevel == SuggestionLevel.error ? 'failed with' : 'reported';
    final issueCounts =
        messages.formatIssueCounts(errorCount, warningCount, hintCount);
    final including = fileAnalyzerItems.length > 5 ? ', including' : '';
    final issueList = fileAnalyzerItems
        .take(5)
        .map((cp) => '\n\nline ${cp.line} col ${cp.col}: ${cp.description}')
        .join();

    final penalty = new Penalty(
        fraction: min(10000, 2000 * errorCount + 500 * warningCount),
        amount: min(
            10000,
            errorPoints.ceil() * errorCount +
                warnPoints.ceil() * warningCount +
                hintPoints.ceil() * hintCount));
    shortcoming += max(penalty.amount, magnitude * penalty.fraction / 10000.0);
    suggestions.add(new Suggestion(
        SuggestionCode.dartanalyzerWarning,
        maxLevel,
        'Fix `$dartFile`.',
        'Analysis of `$dartFile` $failedWith $issueCounts$including:$issueList',
        file: dartFile,
        penalty: penalty));
  }
  suggestions.sort();
  final fitness = new Fitness(magnitude, min(shortcoming, magnitude));
  return new FitnessResult(fitness, suggestions.isEmpty ? null : suggestions);
}

Fitness calcPkgFitness(Iterable<DartFileSummary> files) {
  var magnitude = 0.0;
  var shortcoming = 0.0;
  for (var dfs in files) {
    if (dfs.isInLib && dfs.fitness != null) {
      magnitude += dfs.fitness.magnitude;
      shortcoming += dfs.fitness.shortcoming;
    }
  }
  magnitude = max(1.0, magnitude);

  return new Fitness(magnitude, min(shortcoming, magnitude));
}

final _blockCommentRegExp = new RegExp(r'\/\*.*\*\/', multiLine: true);
final _lineCommentRegExp = new RegExp(r'\/\/.*$');
final _antiSemiColonRegExp = new RegExp(r'[^\;]');
