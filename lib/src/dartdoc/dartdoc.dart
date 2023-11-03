// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model.dart';
import '../report/_common.dart';
import 'dartdoc_index.dart';
import 'index_to_pubdata.dart';
import 'pub_dartdoc_data.dart';

final dartdocSubsectionHeadline =
    '20% or more of the public API has dartdoc comments';

Future<PubDartdocData> generateAndSavePubDataJson(
    String dartdocOutputDir) async {
  final content =
      await File(p.join(dartdocOutputDir, 'index.json')).readAsString();
  final index = DartdocIndex.parseJsonText(content);
  final data = dataFromDartdocIndex(index);
  await File(p.join(dartdocOutputDir, 'pub-data.json'))
      .writeAsString(json.encode(data.toJson()));
  return data;
}

Subsection dartdocFailedSubsection(String reason) {
  return Subsection(
    dartdocSubsectionHeadline,
    [RawParagraph(reason)],
    0,
    10,
    ReportStatus.failed,
  );
}

Future<Subsection> createDocumentationCoverageSection(
    PubDartdocData data) async {
  final documented = data.coverage?.documented ?? 0;
  final total = data.coverage?.total ?? 0;
  final symbolsMissingDocumentation = data.apiElements
      ?.where((e) => e.documentation == null || e.documentation!.isEmpty)
      .map((e) => e.name)
      .toList();

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

  if (symbolsMissingDocumentation != null &&
      symbolsMissingDocumentation.isNotEmpty) {
    summary.write('\n\n'
        'Some symbols that are missing documentation: '
        '${symbolsMissingDocumentation.take(5).map((e) => '`$e`').join(', ')}.');
  }

  return Subsection(
    dartdocSubsectionHeadline,
    [RawParagraph(summary.toString())],
    grantedPoints,
    maxPoints,
    grantedPoints == maxPoints ? ReportStatus.passed : ReportStatus.partial,
  );
}
