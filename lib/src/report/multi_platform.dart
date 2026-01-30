// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../model.dart';
import '../package_context.dart';
import '../sdk_env.dart';
import '../tag/pana_tags.dart';
import '../tag/tagger.dart';
import '_common.dart';

Future<ReportSection> multiPlatform(PackageContext context) async {
  Subsection subsection;
  final flutterPackage = context.pubspec.usesFlutter;

  if (File(
    p.join(context.packageDir, '.dart_tool', 'package_config.json'),
  ).existsSync()) {
    final tags = <String>[];
    final explanations = <Explanation>[];
    final tagger = Tagger(
      context.packageDir,
      dartSdkPath: context.toolEnvironment.dartSdkPath,
    );
    final sdkTags = <String>[];
    final sdkExplanations = <Explanation>[];
    tagger.sdkTags(sdkTags, sdkExplanations);

    String platformList(List<String> tags, Map<String, String> tagNames) {
      return tagNames.entries
          .map((entry) {
            if (tags.contains(entry.key)) {
              return '**${entry.value}**';
            } else {
              return entry.value;
            }
          })
          .join(', ');
    }

    Subsection scorePlatforms(
      List<String> tags,
      List<Explanation> explanations,
    ) {
      // Scoring and the report only takes these platforms into account.
      final tagNames = const {
        PanaTags.platformIos: 'iOS',
        PanaTags.platformAndroid: 'Android',
        PanaTags.platformWeb: 'Web',
        PanaTags.platformWindows: 'Windows',
        PanaTags.platformMacos: 'macOS',
        PanaTags.platformLinux: 'Linux',
      };
      final officialTags = tags.where(tagNames.containsKey).toList();
      final sdkExplanations = explanations.where(
        (e) => e.tag != null && e.tag!.startsWith('sdk:'),
      );
      final platformExplanations = explanations.where(
        (e) => e.tag == null || !e.tag!.startsWith('sdk:'),
      );
      final officialExplanations = platformExplanations.where(
        (e) =>
            !officialTags.contains(e.tag) &&
            (e.tag == null || tagNames.containsKey(e.tag)),
      );
      final trustExplanations = explanations.where((e) => tags.contains(e.tag));
      final paragraphs = <Paragraph>[
        if (sdkExplanations.isNotEmpty) RawParagraph('SDK issues found:'),
        ...sdkExplanations.map(explanationToIssue),
        if (sdkExplanations.isNotEmpty)
          // This empty line is required for `package:markdown` to render the following list correctly.
          RawParagraph(''),
        for (final tag in officialTags.where((e) => e.startsWith('platform')))
          RawParagraph('* ✓ ${tagNames[tag]}'),
        if (officialExplanations.isNotEmpty)
          RawParagraph('\nThese platforms are not supported:\n'),
        ...officialExplanations.map(explanationToIssue),
        if (trustExplanations.isNotEmpty)
          RawParagraph(
            '\nThese issues are present but do not affect the score, because they may not originate in your package:\n',
          ),
        ...trustExplanations.map(explanationToIssue),
      ];

      final status =
          officialTags.where((tag) => tag.startsWith('platform:')).isEmpty
          ? ReportStatus.failed
          : ReportStatus.passed;
      final score = {
        ReportStatus.failed: 0,
        ReportStatus.partial: 10,
        ReportStatus.passed: 20,
      }[status];

      final platforms = platformList(tags, tagNames);
      final description =
          'Supports ${officialTags.length} of '
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

    subsection = scorePlatforms(tags, explanations);
  } else {
    subsection = Subsection(
      'Platform support detection failed',
      [
        Issue(
          'Could not determine supported platforms as package resolution failed.',
          suggestion:
              'Run `${flutterPackage ? 'flutter' : 'dart'} pub get` for more information.',
        ),
      ],
      0,
      20,
      ReportStatus.failed,
    );
  }

  final wasmSubsection = await _createWasmSubsection(context);
  final swiftPackageManagerSubsection =
      await _createSwiftPackageManagerSubSection(context);

  return makeSection(
    id: ReportSectionId.platform,
    title: 'Platform support',
    maxPoints: 20,
    basePath: context.packageDir,
    subsections: [
      subsection,
      ?wasmSubsection,
      if (swiftPackageManagerSubsection != null) swiftPackageManagerSubsection,
    ],
    maxIssues: 20,
  );
}

Future<Subsection?> _createWasmSubsection(PackageContext context) async {
  final tr = await context.staticAnalysis;
  final description = 'WASM compatibility';
  final explanation = tr.explanations
      .where((e) => e.tag == PanaTags.isWasmReady)
      .firstOrNull;
  if (!tr.tags.contains(PanaTags.platformWeb)) return null;
  if (explanation != null) {
    return Subsection(
      description,
      [
        explanationToIssue(explanation),
        RawParagraph(
          'This package is not compatible with runtime `wasm`, and will not be rewarded '
          'full points in a future version of the scoring model.',
        ),
        RawParagraph('See https://dart.dev/web/wasm for details.'),
      ],
      0,
      0,
      ReportStatus.failed,
    );
  }

  if (tr.tags.contains(PanaTags.isWasmReady)) {
    return Subsection(
      description,
      [
        RawParagraph(
          'This package is compatible with runtime `wasm`, and will be rewarded '
          'additional points in a future version of the scoring model.',
        ),
        RawParagraph('See https://dart.dev/web/wasm for details.'),
      ],
      0,
      0,
      ReportStatus.passed,
    );
  } else {
    return Subsection(
      description,
      [
        RawParagraph(
          'Unable to detect compatibility with runtime `wasm`, and this package will not '
          'be rewarded full points in a future version of the scoring model.',
        ),
        RawParagraph('See https://dart.dev/web/wasm for details.'),
      ],
      0,
      0,
      ReportStatus.failed,
    );
  }
}

/// Create a subsection for ios and macos plugins, to highlight supported
/// for swift package manager (or lack there of).
Future<Subsection?> _createSwiftPackageManagerSubSection(
  PackageContext context,
) async {
  final tr = await context.staticAnalysis;
  final description = 'Swift Package Manager support';

  if (tr.tags.contains(PanaTags.isSwiftPmPlugin)) {
    return Subsection(
      description,
      [
        RawParagraph(
          'This iOS or macOS plugin supports the Swift Package Manager. '
          'It will be rewarded additional points in a future version of the scoring model.',
        ),
        RawParagraph('See https://docs.flutter.dev/to/spm for details.'),
      ],
      0,
      0,
      ReportStatus.passed,
    );
  }
  final explanation = tr.explanations
      .where((e) => e.tag == PanaTags.isSwiftPmPlugin)
      .firstOrNull;
  if (explanation != null) {
    return Subsection(
      description,
      [
        explanationToIssue(explanation),
        RawParagraph(
          'This package for iOS or macOS does not support the Swift Package Manager. '
          'It will not receive full points in a future version of the scoring model.',
        ),
        RawParagraph('See https://docs.flutter.dev/to/spm for details.'),
      ],
      0,
      0,
      ReportStatus.failed,
    );
  }
  // Don't complain if this is not an ios/macos plugin.
  return null;
}
