// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

import 'create_report.dart' show renderSimpleSectionSummary;
import 'model.dart';
import 'sdk_env.dart';

const documentationSectionTitle = 'Provide documentation';

/// Creates a report section about documentation coverage.
/// 20% coverage grants the maximum number of points.
ReportSection documentationCoverageSection({
  @required int documented,
  @required int total,
}) {
  final maxPoints = 10;
  final ratio = total <= 0 ? 1.0 : documented / total;
  final accepted = ratio >= 0.2;
  final percent = (100.0 * ratio).toStringAsFixed(1);
  final summary = StringBuffer();
  final grantedPoints = accepted ? maxPoints : 0;

  summary.write(
      '$documented out of $total API elements ($percent %) have documentation comments.');

  if (!accepted) {
    summary.write('\n\n'
        'Providing good documentation for libraries, classes, functions, and other API '
        'elements improves code readability and helps developers find and use your API. '
        'Document at least 20% of the public API elements.');
  }

  return ReportSection(
    title: documentationSectionTitle,
    grantedPoints: grantedPoints,
    maxPoints: maxPoints,
    summary: renderSimpleSectionSummary(
      title: '20% or more of the public API has dartdoc comments',
      description: summary.toString(),
      grantedPoints: grantedPoints,
      maxPoints: 10,
    ),
  );
}

/// Creates a report section when running dartdoc failed to produce content.
ReportSection dartdocFailedSection([DartdocResult result]) {
  final errorMessage = result?.processResult?.stderr?.toString() ?? '';

  return ReportSection(
    title: documentationSectionTitle,
    grantedPoints: 0,
    maxPoints: 10,
    summary: renderSimpleSectionSummary(
      title: 'Failed to run dartdoc',
      description:
          'Running `dartdoc` failed with the following output:\n\n```\n$errorMessage\n```\n',
      grantedPoints: 0,
      maxPoints: 10,
    ),
  );
}
