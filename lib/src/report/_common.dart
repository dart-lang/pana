// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../model.dart';
import '../tag/_common.dart';

const maxSourceSpanLength = 512;

/// Loads [SourceSpan] on-demand.
typedef SourceSpanFn = SourceSpan? Function();

extension on SourceSpan {
  /// An attempt to render [SourceSpan]s in a markdown-friendly way.
  ///
  /// The file path will be relative to [basePath].
  String markdown({String? basePath}) {
    assert(sourceUrl != null);
    final path = p.relative(sourceUrl!.path, from: basePath);
    return '`$path:${start.line + 1}:${start.column + 1}`\n\n'
        '```\n${highlight()}\n```\n';
  }
}

abstract class Paragraph {
  String markdown({String? basePath});
}

class RawParagraph implements Paragraph {
  final String _markdown;

  RawParagraph(this._markdown);

  @override
  String markdown({String? basePath}) => _markdown;
}

/// A single issue found by the analysis.
///
/// This is not part of the external data-model, but used for gathering
/// sub-problems for making a [ReportSection] summary.
class Issue implements Paragraph {
  /// Markdown description of the issue.
  final String description;

  /// Source location of the problem in [span].
  ///
  /// If we know nothing more than the file the problem occurs in (no specific
  /// line numbers), that file path should be included in [description].
  final SourceSpan? span;

  /// Similar to [span], but with deferred loading from the filesystem.
  ///
  /// [SourceSpanFn] may return `null`, if when loaded the offset is invalid.
  final SourceSpanFn? spanFn;

  /// Can be used for giving a potential solution of the issue, and
  /// also for a command to reproduce locally.
  final String? suggestion;

  Issue(this.description, {this.span, this.spanFn, this.suggestion});

  @override
  String markdown({String? basePath}) {
    final span = this.span ?? (spanFn == null ? null : spanFn!());
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

class Subsection {
  final List<Paragraph> issues;
  final String description;
  final int grantedPoints;
  final int maxPoints;
  final String bodyPrefix;

  final ReportStatus status;

  Subsection(
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
String _makeSummary(List<Subsection> subsections,
    {String? introduction, String? basePath, int maxIssues = 2}) {
  return [
    if (introduction != null) introduction,
    ...subsections.map((subsection) {
      final issuesMarkdown =
          subsection.issues.map((e) => e.markdown(basePath: basePath));
      final statusMarker = _reportStatusMarker(subsection.status);
      return [
        '### $statusMarker ${subsection.grantedPoints}/${subsection.maxPoints} points: ${subsection.description}\n',
        if (subsection.bodyPrefix.isNotEmpty) subsection.bodyPrefix,
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

String? _reportStatusMarker(ReportStatus status) => const {
      ReportStatus.passed: '[*]',
      ReportStatus.failed: '[x]',
      ReportStatus.partial: '[~]'
    }[status];

/// Renders a summary block for sections that can have only a single issue.
String renderSimpleSectionSummary({
  required String title,
  required String? description,
  required int grantedPoints,
  required int maxPoints,
}) {
  return _makeSummary([
    Subsection(
      title,
      [if (description != null) Issue(description)],
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

ReportSection makeSection(
    {required String id,
    required String title,
    required int maxPoints,
    required List<Subsection> subsections,
    required String? basePath,
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

SourceSpan? tryGetSpanFromYamlMap(Object map, String key) {
  if (map is YamlMap) {
    final span = map.nodes[key]?.span;
    if (span != null && span.length > maxSourceSpanLength) {
      return SourceSpan(
        span.start,
        SourceLocation(span.start.offset + maxSourceSpanLength),
        span.text.substring(0, maxSourceSpanLength),
      );
    } else {
      return span;
    }
  }
  return null;
}

Issue explanationToIssue(Explanation explanation) =>
    Issue(explanation.finding, suggestion: explanation.explanation);
