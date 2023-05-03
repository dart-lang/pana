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
  final dart3Label = context.usesFlutter ? 'Dart 3 & Flutter 3.10' : 'Dart 3';
  try {
    final problems = await context.codeProblemsWithFutureSdk;
    final errors = problems.where((e) => e.isError).toList();
    if (errors.isEmpty) {
      subsection = Subsection(
        'Package is $dart3Label compatible!',
        [],
        maxPoints,
        maxPoints,
        ReportStatus.passed,
      );
    } else {
      subsection = Subsection(
        '$dart3Label compatibility has one or more issues.',
        errors
            .take(5)
            .map((e) => Issue(
                  '${e.severity}: ${e.description}',
                  suggestion:
                      'To reproduce make sure you are using $dart3Label and '
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
      'Unable to detect $dart3Label compatibility',
      [
        Issue(
            'Failed to analyze $dart3Label compatibilty:\n```\n${e.message}\n${e.stderr}\n```\n'),
      ],
      0,
      maxPoints,
      ReportStatus.failed,
    );
  }
  return makeSection(
    title: '$dart3Label compatibility',
    maxPoints: maxPoints,
    id: ReportSectionId.dart3Compatiblity,
    subsections: [subsection],
    basePath: context.packageDir,
  );
}
