// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../dartdoc_analyzer.dart';
import '../maintenance.dart';
import '../model.dart';
import '../pubspec.dart';

import '_common.dart';

Future<ReportSection> hasDocumentation(
    String packageDir, Pubspec pubspec) async {
  // TODO: run dartdoc for coverage

  final candidates = exampleFileCandidates(pubspec.name, caseSensitive: true);
  final examplePath = candidates
      .firstWhereOrNull((c) => File(p.join(packageDir, c)).existsSync());
  final issues = <Issue>[
    if (examplePath == null)
      Issue(
        'No example found.',
        suggestion:
            'See [package layout](https://dart.dev/tools/pub/package-layout#examples) '
            'guidelines on how to add an example.',
      )
    else
      Issue('Found example at: `$examplePath`')
  ];

  final points = examplePath == null ? 0 : 10;
  final status =
      examplePath == null ? ReportStatus.failed : ReportStatus.passed;
  return makeSection(
    id: ReportSectionId.documentation,
    title: documentationSectionTitle,
    maxPoints: 10,
    subsections: [
      Subsection('Package has an example', issues, points, 10, status)
    ],
    basePath: null,
  );
}
