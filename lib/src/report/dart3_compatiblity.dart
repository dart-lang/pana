// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

import '../model.dart';
import '../package_context.dart';
import '../sdk_env.dart';

import '_common.dart';
import 'static_analysis.dart';

Future<ReportSection> dart3Compatibility(PackageContext context) async {
  final maxPoints = 20;
  late Subsection subsection;
  try {
    final problems = await context.codeProblemsWithFutureSdk;
    final errors = problems.where((e) => e.isError).toList();
    if (errors.isEmpty) {
      subsection = Subsection(
        'Package is Dart 3 compatible!',
        [],
        maxPoints,
        maxPoints,
        ReportStatus.passed,
      );
    } else {
      subsection = Subsection(
        'Dart 3 compatibility has one or more issues.',
        errors
            .take(5)
            .map((e) => Issue(
                  '${e.severity}: ${e.description}',
                  suggestion: 'To reproduce make sure you are using Dart 3 and '
                      'run `${context.usesFlutter ? 'flutter analyze' : 'dart analyze'} ${e.file}`',
                  spanFn: () => sourceSpanFromFile(
                    path: p.join(context.packageDir, e.file),
                    line: e.line,
                    col: e.col,
                    length: e.length,
                  ),
                ))
            .toList(),
        0,
        maxPoints,
        ReportStatus.failed,
      );
    }
  } on ToolException catch (e) {
    subsection = subsection = Subsection(
      'Unable to detect Dart 3 compatibility',
      [
        Issue(
            'Failed to analyze Dart 3 compatibilty:\n```\n${e.message}\n${e.stderr}\n```\n'),
      ],
      0,
      maxPoints,
      ReportStatus.failed,
    );
  }
  return makeSection(
    title: 'Dart 3 compatibility',
    maxPoints: maxPoints,
    id: ReportSectionId.dart3Compatiblity,
    subsections: [subsection],
    basePath: context.packageDir,
  );
}
