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

  final templateReport = await followsTemplate(context);
  final platformReport = await multiPlatform(context.packageDir, pubspec);
  final staticAnalysisReport = await staticAnalysis(context);
  final dependenciesReport = await trustworthyDependency(context);

  // Create the documentation report (and run `dartdoc`) as the last step
  // to allow better budgeting for large packages.
  final documentationReport = await hasDocumentation(context);

  return Report(sections: [
    templateReport,
    documentationReport,
    platformReport,
    staticAnalysisReport,
    dependenciesReport,
  ]);
}
