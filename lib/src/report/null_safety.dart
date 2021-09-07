// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../model.dart';
import '../pubspec.dart';
import '../tag/tagger.dart';

import '_common.dart';

Future<ReportSection> nullSafety(String packageDir, Pubspec pubspec) async {
  const maxPoints = 20;

  Subsection subsection;
  if (File(p.join(packageDir, '.dart_tool', 'package_config.json'))
      .existsSync()) {
    final tagger = Tagger(packageDir);

    final nullSafetyTags = <String>[];
    final explanations = <Explanation>[];
    tagger.nullSafetyTags(nullSafetyTags, explanations);
    if (pubspec.sdkConstraintStatus.hasOptedIntoNullSafety) {
      if (nullSafetyTags.contains('is:null-safe')) {
        subsection = Subsection(
            'Package and dependencies are fully migrated to null safety!',
            explanations.map(explanationToIssue).toList(),
            maxPoints,
            maxPoints,
            ReportStatus.passed);
      } else {
        subsection = Subsection(
            'Null safety support has one or more issues.',
            [
              ...explanations.map(explanationToIssue).toList(),
              // TODO(sigurdm): This is no longer enough, because `dart pub outdated`
              // got a more simplistic analysis. We need a better explanation
              // here.
              Issue(
                'For more information',
                suggestion:
                    'Try running `dart pub outdated --mode=null-safety`.\n'
                    'Be sure to read the [migration guide](https://dart.dev/null-safety/migration-guide).',
              )
            ],
            0,
            maxPoints,
            ReportStatus.failed);
      }
    } else {
      subsection = Subsection(
          'Package does not opt in to null safety.',
          [
            Issue(
              'Package language version (indicated by the sdk constraint '
              '`${pubspec.dartSdkConstraint}`) is less than 2.12.',
              suggestion:
                  'Consider [migrating](https://dart.dev/null-safety/migration-guide).',
            )
          ],
          0,
          maxPoints,
          ReportStatus.partial);
    }
  } else {
    subsection = Subsection(
      'Unable to detect null safety',
      [
        Issue('Package resolution failed. Could not determine null safety.',
            suggestion: 'Run `dart pub get` for more information.')
      ],
      0,
      maxPoints,
      ReportStatus.failed,
    );
  }
  return makeSection(
    title: 'Support sound null safety',
    maxPoints: maxPoints,
    id: ReportSectionId.nullSafety,
    subsections: [subsection],
    basePath: packageDir,
    maxIssues:
        100, // Tagging produces a bounded number of issues. Better display them all.
  );
}
