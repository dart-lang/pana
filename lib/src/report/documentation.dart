// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../dartdoc/dartdoc.dart';
import '../dartdoc_analyzer.dart';
import '../maintenance.dart';
import '../model.dart';
import '../package_context.dart';

import '_common.dart';

Future<Subsection> _exampleSubsection(PackageContext context) async {
  final packageDir = context.packageDir;
  final pubspec = context.pubspec;
  final candidates = exampleFileCandidates(pubspec.name);
  // Because we care about the file-names case, we first list all files, and
  // then test for presence of candidates in that list.
  //
  // This should work on case-preserving but insensitive file-systems.
  final files = Directory(packageDir).listSync(recursive: true).map(
      (e) => p.posix.joinAll(p.split(p.relative(e.path, from: packageDir))));
  final examplePath = candidates.firstWhereOrNull(files.contains);
  final issues = <Issue>[
    if (examplePath == null)
      Issue(
        'No example found.',
        suggestion:
            'See [package layout](https://dart.dev/tools/pub/package-layout#examples) '
            'guidelines on how to add an example.',
      )
  ];

  final screenshotIssues = <Issue>[];
  final declaredScreenshots = pubspec.screenshots;

  final screenshotResults = await context.screenshots;
  for (var result in screenshotResults) {
    screenshotIssues.addAll(result.problems.map(Issue.new));
  }

  issues.addAll(screenshotIssues);

  final headline = declaredScreenshots.isNotEmpty
      ? 'Package has an example and has no issues with screenshots'
      : 'Package has an example';
  final status = screenshotIssues.isEmpty && examplePath != null
      ? ReportStatus.passed
      : ReportStatus.failed;
  final points = status == ReportStatus.passed ? 10 : 0;
  return Subsection(headline, issues, points, 10, status);
}

Future<ReportSection> hasDocumentation(PackageContext context) async {
  final dartdocResult = await context.dartdocResult;
  final dartdocPubData = await context.dartdocPubData;
  Subsection? documentation;
  if (dartdocPubData != null) {
    documentation = await createDocumentationCoverageSection(dartdocPubData);
  } else if (dartdocResult != null) {
    documentation = dartdocFailedSubsection(
        dartdocResult.errorReason ?? 'Running or processing dartdoc failed.');
  }

  final example = await _exampleSubsection(context);
  return makeSection(
    id: ReportSectionId.documentation,
    title: documentationSectionTitle,
    maxPoints: (documentation?.maxPoints ?? 0) + example.maxPoints,
    subsections: [
      if (documentation != null) documentation,
      example,
    ],
    basePath: null,
  );
}
