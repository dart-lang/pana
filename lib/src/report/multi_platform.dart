// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../model.dart';
import '../pubspec.dart';
import '../tag/pana_tags.dart';
import '../tag/tagger.dart';
import '_common.dart';

Future<ReportSection> multiPlatform(String packageDir, Pubspec pubspec) async {
  Subsection subsection;
  final flutterPackage = pubspec.usesFlutter;

  if (File(p.join(packageDir, '.dart_tool', 'package_config.json'))
      .existsSync()) {
    final tags = <String>[];
    final explanations = <Explanation>[];
    final tagger = Tagger(packageDir);
    final sdkTags = <String>[];
    final sdkExplanations = <Explanation>[];
    tagger.sdkTags(sdkTags, sdkExplanations);

    String platformList(List<String> tags, Map<String, String> tagNames) {
      return tagNames.entries.map((entry) {
        if (tags.contains(entry.key)) {
          return '**${entry.value}**';
        } else {
          return entry.value;
        }
      }).join(', ');
    }

    Subsection scorePlatforms(
        List<String> tags, List<Explanation> explanations) {
      final tagNames = const {
        PanaTags.platformIos: 'iOS',
        PanaTags.platformAndroid: 'Android',
        PanaTags.platformWeb: 'Web',
        PanaTags.platformWindows: 'Windows',
        PanaTags.platformMacos: 'macOS',
        PanaTags.platformLinux: 'Linux',
      };
      final sdkExplanations =
          explanations.where((e) => e.tag != null && e.tag!.startsWith('sdk:'));
      final platformExplanations = explanations
          .where((e) => e.tag == null || !e.tag!.startsWith('sdk:'));
      final officialExplanations = platformExplanations.where((e) =>
          !tags.contains(e.tag) &&
          (e.tag == null || tagNames.containsKey(e.tag)));
      final trustExplanations = explanations.where((e) => tags.contains(e.tag));
      final paragraphs = <Paragraph>[
        if (sdkExplanations.isNotEmpty) RawParagraph('SDK issues found:'),
        ...sdkExplanations.map(explanationToIssue),
        if (sdkExplanations.isNotEmpty)
          // This empty line is required for `package:markdown` to render the following list correctly.
          RawParagraph(''),
        for (final tag in tags.where((e) => e.startsWith('platform')))
          RawParagraph('* ✓ ${tagNames[tag]}'),
        if (officialExplanations.isNotEmpty)
          RawParagraph('\nThese platforms are not supported:\n'),
        ...officialExplanations.map(explanationToIssue),
        if (trustExplanations.isNotEmpty)
          RawParagraph(
              '\nThese issues are present but do not affect the score, because they may not originate in your package:\n'),
        ...trustExplanations.map(explanationToIssue),
      ];

      final officialTags = tags.where(tagNames.containsKey).toList();

      final status =
          officialTags.where((tag) => tag.startsWith('platform:')).isEmpty
              ? ReportStatus.failed
              : ReportStatus.passed;
      final score = {
        ReportStatus.failed: 0,
        ReportStatus.partial: 10,
        ReportStatus.passed: 20
      }[status];

      final platforms = platformList(tags, tagNames);
      final description = 'Supports ${officialTags.length} of '
          '${tagNames.length} possible platforms ($platforms)';
      return Subsection(description, paragraphs, score!, 20, status);
    }

    tagger.platformTags(tags, explanations, trustDeclarations: true);
    if (!flutterPackage) {
      tagger.runtimeTags(tags, explanations);
      // We don't want the native-aot runtime to be explained here.
      explanations.removeWhere(
        (explanation) => explanation.tag == Runtime.nativeAot.tag,
      );
    }

    subsection = scorePlatforms(
      tags,
      explanations,
    );
  } else {
    subsection = Subsection(
      'Platform support detection failed',
      [
        Issue(
          'Could not determine supported platforms as package resolution failed.',
          suggestion:
              'Run `${flutterPackage ? 'flutter' : 'dart'} pub get` for more information.',
        )
      ],
      0,
      20,
      ReportStatus.failed,
    );
  }

  return makeSection(
      id: ReportSectionId.platform,
      title: 'Platform support',
      maxPoints: 20,
      basePath: packageDir,
      subsections: [subsection],
      maxIssues: 20);
}
