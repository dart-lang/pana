// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../model.dart';
import '../pubspec.dart';
import '../tag/tagger.dart';

import '_common.dart';

Future<ReportSection> multiPlatform(String packageDir, Pubspec pubspec) async {
  Subsection subsection;
  if (File(p.join(packageDir, '.dart_tool', 'package_config.json'))
      .existsSync()) {
    final tags = <String>[];
    final explanations = <Explanation>[];
    final tagger = Tagger(packageDir);
    final sdkTags = <String>[];
    final sdkExplanations = <Explanation>[];
    tagger.sdkTags(sdkTags, sdkExplanations);

    final flutterPackage = pubspec.usesFlutter;

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
        Map<String, String> tagNames,
        ReportStatus Function(int) statusFromCount,
        List<String> tags,
        List<Explanation> explanations) {
      final sdkExplanations =
          explanations.where((e) => e.tag != null && e.tag!.startsWith('sdk:'));
      final platformExplanations = explanations
          .where((e) => e.tag == null || !e.tag!.startsWith('sdk:'));
      final unofficialExplanations = platformExplanations.where((e) =>
          !tags.contains(e.tag) &&
          (e.tag != null &&
              !e.tag!.startsWith('sdk:') &&
              !tagNames.containsKey(e.tag)));
      final officialExplanations = platformExplanations.where((e) =>
          !tags.contains(e.tag) &&
          (e.tag == null || tagNames.containsKey(e.tag)));
      final trustExplanations = explanations.where((e) => tags.contains(e.tag));
      final paragraphs = [
        if (sdkExplanations.isNotEmpty) RawParagraph('SDK issues found:'),
        ...sdkExplanations.map(explanationToIssue),
        if (officialExplanations.isNotEmpty)
          RawParagraph('\nConsider supporting multiple platforms:\n'),
        ...officialExplanations.map(explanationToIssue),
        if (unofficialExplanations.isNotEmpty)
          RawParagraph('\nConsider supporting these prerelease platforms:\n'),
        ...unofficialExplanations.map(explanationToIssue),
        if (trustExplanations.isNotEmpty)
          RawParagraph(
              '\nThese issues are present but do not affect the score, because they may not originate in your package:\n'),
        ...trustExplanations.map(explanationToIssue),
      ];

      final officialTags = tags.where(tagNames.containsKey).toList();
      final status = statusFromCount(officialTags.length);
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

    if (flutterPackage) {
      tagger.flutterPlatformTags(tags, explanations, trustDeclarations: true);
      final tagNames = const {
        'platform:ios': 'iOS',
        'platform:android': 'Android',
        'platform:web': 'Web',
      };
      subsection = scorePlatforms(
        tagNames,
        (count) => count <= 1
            ? ReportStatus.failed
            : (count == 2 ? ReportStatus.partial : ReportStatus.passed),
        tags,
        explanations,
      );
    } else {
      tagger.runtimeTags(tags, explanations);

      final tagNames = const {
        'runtime:native-jit': 'native',
        'runtime:web': 'js',
      };

      // We don't want the native-aut runtime to be explained here.
      explanations.removeWhere(
          (explanation) => explanation.tag == Runtime.nativeAot.tag);

      subsection = scorePlatforms(
        tagNames,
        (count) => count == 0
            ? ReportStatus.failed
            : (count == 1 ? ReportStatus.partial : ReportStatus.passed),
        tags,
        explanations,
      );
    }
  } else {
    subsection = Subsection(
      'Supports 0 of 2 possible platforms (native, js)',
      [
        Issue('Package resolution failed. Could not determine platforms.',
            suggestion: 'Run `dart pub get` for more information.')
      ],
      0,
      20,
      ReportStatus.failed,
    );
  }

  return makeSection(
      id: ReportSectionId.platform,
      title: 'Support multiple platforms',
      maxPoints: 20,
      basePath: packageDir,
      subsections: [subsection]);
}
