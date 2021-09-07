// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../model.dart';
import '../package_context.dart';
import '../pubspec.dart';

import 'dependencies.dart';
import 'documentation.dart';
import 'multi_platform.dart';
import 'null_safety.dart';
import 'static_analysis.dart';
import 'template.dart';

export '_common.dart' show renderSimpleSectionSummary;

Future<Report> createReport(PackageContext context) async {
  Pubspec pubspec;
  try {
    pubspec = context.pubspec;
  } on Exception catch (e) {
    return Report(
      sections: [
        ReportSection(
          id: ReportSectionId.convention,
          grantedPoints: 0,
          maxPoints: 100,
          title: 'Failed to parse the pubspec',
          summary: e.toString(),
          status: ReportStatus.failed,
        )
      ],
    );
  }

  return Report(sections: [
    await followsTemplate(context),
    await hasDocumentation(context.packageDir, pubspec),
    await multiPlatform(context.packageDir, pubspec),
    await staticAnalysis(context),
    await trustworthyDependency(context),
    await nullSafety(context.packageDir, pubspec),
  ]);
}
