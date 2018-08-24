// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.health;

import 'package:meta/meta.dart';

import 'messages.dart' as messages;
import 'model.dart';
import 'pubspec.dart';

/// Extracts and summarizes the output of `dartanalyzer` and `dartfmt`.
Health calcHealth({
  @required Pubspec pubspec,
  @required List<CodeProblem> analyzerItems,
  @required Iterable<DartFileSummary> dartFileSummaries,
}) {
  analyzerItems ??= const <CodeProblem>[];
  final analyzerErrorCount = analyzerItems.where((c) => c.isError).length;
  final analyzerWarningCount = analyzerItems.where((c) => c.isWarning).length;
  final analyzerHintCount = analyzerItems.where((c) => c.isInfo).length;
  var platformConflictCount = 0;
  final suggestions = <Suggestion>[];

  for (final s in dartFileSummaries) {
    if (s.platform != null && s.platform.hasConflict) {
      platformConflictCount++;
      final components = s.platform.components?.map((s) => '`$s`')?.join(', ');
      var description =
          'Make sure that the imported libraries are not in conflict.';
      if (components != null) {
        description += ' Detected components: $components.';
      }
      if (s.platform.reason != null && s.platform.reason.isNotEmpty) {
        description += ' ${s.platform.reason}';
      }
      suggestions.add(new Suggestion.error(
        SuggestionCode.platformConflictInFile,
        'Fix platform conflict in `${s.path}`.',
        description,
        file: s.path,
        score: 25.0,
      ));
    }

    if (s.isFormatted == false) {
      suggestions.add(new Suggestion.hint(
        SuggestionCode.dartfmtWarning,
        'Format `${s.path}`.',
        messages.runDartfmtToFormatFile(pubspec.usesFlutter, s.path),
        file: s.path,
      ));
    }
  }

  final reportedFiles = analyzerItems.map((cp) => cp.file).toSet();
  for (final path in reportedFiles) {
    final fileAnalyzerItems =
        analyzerItems.where((cp) => cp.file == path).toList();
    if (fileAnalyzerItems.isNotEmpty) {
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

      suggestions.add(new Suggestion(
        SuggestionCode.dartanalyzerWarning,
        maxLevel,
        'Fix `$path`.',
        'Analysis of `$path` $failedWith $issueCounts$including:$issueList',
        file: path,
      ));
    }
  }

  suggestions.sort();

  return new Health(
    analyzerErrorCount: analyzerErrorCount,
    analyzerWarningCount: analyzerWarningCount,
    analyzerHintCount: analyzerHintCount,
    platformConflictCount: platformConflictCount,
    suggestions: _compact(suggestions, analyzerItems),
  );
}

List<Suggestion> _compact(
    List<Suggestion> allSuggestions, List<CodeProblem> analyzerItems) {
  final suggestions = <Suggestion>[];

  final reportedFiles = new Set();
  final onePerFileSuggestions =
      allSuggestions.where((s) => reportedFiles.add(s.file)).toList()..sort();

  if (onePerFileSuggestions.length < 6) {
    suggestions.addAll(onePerFileSuggestions);
  } else {
    final takeItemCount = 3;
    final topSuggestions = onePerFileSuggestions.take(takeItemCount).toList();
    final restSuggestions = onePerFileSuggestions.skip(takeItemCount).toList();
    suggestions.addAll(topSuggestions);

    if (restSuggestions.isNotEmpty) {
      final sb = new StringBuffer();
      sb.write('Additional issues in the following files:\n\n');

      for (final s in restSuggestions) {
        final fileAnalyzerItems =
            analyzerItems.where((cp) => cp.file == s.file).toList();

        if (fileAnalyzerItems.isNotEmpty) {
          final errorCount = fileAnalyzerItems.where((cp) => cp.isError).length;
          final warningCount =
              fileAnalyzerItems.where((cp) => cp.isWarning).length;
          final hintCount = fileAnalyzerItems.where((cp) => cp.isInfo).length;
          final issueCounts =
              messages.formatIssueCounts(errorCount, warningCount, hintCount);
          sb.writeln('- `${s.file}` ($issueCounts)');
        } else {
          sb.writeln('- `${s.file}` (${s.description})');
        }
      }

      final hasError = restSuggestions.where((s) => s.isError).isNotEmpty;
      final hasWarning = restSuggestions.where((s) => s.isWarning).isNotEmpty;
      final level = hasError
          ? SuggestionLevel.error
          : (hasWarning ? SuggestionLevel.warning : SuggestionLevel.hint);

      suggestions.add(
        new Suggestion(
          SuggestionCode.bulk,
          level,
          'Fix additional ${restSuggestions.length} files with analysis or formatting issues.',
          sb.toString(),
        ),
      );
    }
  }

  suggestions.sort();
  return suggestions;
}
