// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
    _supportsDart2(pubspec),
    // TODO(sigurdm):Implement rest of sections.
  ]);
}

ReportSection _supportsDart2(Pubspec pubspec) {
  final supportsDart2 = pubspec.supportsDart2;
  final issues = <_Issue>[];

  if (!supportsDart2) {
    final environment = pubspec.toJson()['environment'] as Map;
    SourceSpan span;
    if (environment is YamlMap) {
      final sdk = environment.nodes['sdk'];
      if (sdk is YamlNode) {
        span = sdk.span;
      }
    }

    issues.add(
      _Issue(
        'The current sdk constraint does not allow any Dart 2 versions',
        span: span,
      ),
    );
  }

  return ReportSection(
      title: 'Package supports Dart 2',
      maxPoints: 20,
      grantedPoints: supportsDart2 ? 20 : 0,
      summary: _makeSummary(
          'Package gets 20 points if their dart sdk constraint allows Dart 2',
          issues));
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

  @override
  String toString() {
    return [
      description,
      if (span != null) span.markdown,
      if (suggestion != null) suggestion
    ].join('\n');
  }
}

extension on SourceSpan {
  /// An attempt to render [SourceSpan]s in a markdown-friendly way
  String get markdown {
    assert(sourceUrl != null);
    return '<${p.prettyUri(sourceUrl)}>:${start.line + 1}:${start.column + 1}\n\n'
        '```${highlight()}```\n';
  }
}

/// Given an introduction and a list of issues, formats the summary of a
/// section.
String _makeSummary(String introduction, List<_Issue> issues) {
  return [
    introduction,
    if (issues.isNotEmpty) ...[
      '',
      if (issues.length <= 2)
        ...issues
      else ...[
        'Found ${issues.length} issues. Showing the first two:',
        ...issues.take(2).map((x) => x.toString()),
      ],
    ],
  ].join('\n');
}
