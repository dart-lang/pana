// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../model.dart';
import '../package_context.dart';
import '../tag/pana_tags.dart';
import '../tag/tagger.dart';
import '_common.dart';

Future<ReportSection> multiPlatform(PackageContext context) async {
  Subsection subsection;
  final flutterPackage = context.pubspec.usesFlutter;
  final analysisResult = await context.staticAnalysis;
  final analysisCompleted =
      analysisResult.items != null && !analysisResult.hasError;
  final hasPackageConfig = File(
    p.join(context.packageDir, '.dart_tool', 'package_config.json'),
  ).existsSync();

  if (hasPackageConfig && analysisCompleted) {
    final tags = analysisResult.tags;
    final explanations = [...analysisResult.explanations];

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

    // Ignore some explanations that may be trivial in the given scope.
    final hasAnySdk = tags.any((tag) => tag.startsWith('sdk:'));
    final hasAnyPlatform = tags.any((tag) => tag.startsWith('platform:'));
    final sdkExplanations = hasAnySdk
        ? <Explanation>[]
        : explanations
              .where((e) => e.tag != null && e.tag!.startsWith('sdk:'))
              .whereNot(
                (e) =>
                    hasAnyPlatform &&
                    flutterPackage &&
                    e.tag == PanaTags.sdkDart,
              );

    if (!flutterPackage) {
      // We don't want the native-aot runtime to be explained here.
      explanations.removeWhere(
        (explanation) => explanation.tag == Runtime.nativeAot.tag,
      );
    }

    // Get WASM and Swift PM information from static analysis
    final hasWebPlatform = tags.contains(PanaTags.platformWeb);
    final isWasmReady = tags.contains(PanaTags.isWasmReady);
    final wasmExplanations = explanations
        .where((e) => e.tag == PanaTags.isWasmReady)
        .toList();

    final hasIosOrMacosPlatform =
        tags.contains(PanaTags.platformIos) ||
        tags.contains(PanaTags.platformMacos);
    final needsToBeSwiftPmReady =
        tags.contains(PanaTags.isPlugin) && hasIosOrMacosPlatform;
    final isSwiftPmReady = tags.contains(PanaTags.isSwiftPmPlugin);
    final swiftPmExplanations = explanations
        .where((e) => e.tag == PanaTags.isSwiftPmPlugin)
        .toList();

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
    final platformExplanations = explanations.where(
      (e) => e.tag == null || e.tag!.startsWith('platform:'),
    );
    final officialExplanations = platformExplanations.where(
      (e) =>
          !officialTags.contains(e.tag) &&
          (e.tag == null || tagNames.containsKey(e.tag)),
    );
    final trustExplanations = explanations.where((e) => tags.contains(e.tag));
    final paragraphs = <Paragraph>[
      if (sdkExplanations.isNotEmpty) ...[
        RawParagraph('SDK issues found:'),
        ...sdkExplanations.map(explanationToIssue),
        RawParagraph(''), // force empty line in markdown
      ],
      for (final tag in officialTags.where((e) => e.startsWith('platform')))
        RawParagraph('* ✓ ${tagNames[tag]}'),
      if (officialExplanations.isNotEmpty) ...[
        RawParagraph('\nThese platforms are not supported:\n'),
        ...officialExplanations.map(explanationToIssue),
      ],
      if (trustExplanations.isNotEmpty) ...[
        RawParagraph(
          '\nThese issues are present but do not affect the score, because they may not originate in your package:\n',
        ),
        ...trustExplanations.map(explanationToIssue),
      ],
      // WASM
      if (hasWebPlatform && wasmExplanations.isNotEmpty) ...[
        RawParagraph('\nWASM compatibility:'),
        ...wasmExplanations.map(explanationToIssue),
      ],
      if (hasWebPlatform && !isWasmReady)
        RawParagraph(
          '\n**Note:** This package supports Web but is not WASM-compatible, '
          'resulting in a partial score. See https://dart.dev/web/wasm for details.',
        ),
      if (hasWebPlatform && isWasmReady)
        RawParagraph(
          '\n**WASM-ready:** This package is compatible with runtime `wasm`. '
          'See https://dart.dev/web/wasm for details.',
        ),
      // Swift Package Manager
      if (needsToBeSwiftPmReady && swiftPmExplanations.isNotEmpty) ...[
        RawParagraph('\nSwift Package Manager support:'),
        ...swiftPmExplanations.map(explanationToIssue),
      ],
      if (needsToBeSwiftPmReady && !isSwiftPmReady)
        RawParagraph(
          '\n**Note:** This iOS or macOS plugin does not support the Swift Package Manager, '
          'resulting in a partial score. See https://docs.flutter.dev/to/spm for details.',
        ),
      if (needsToBeSwiftPmReady && isSwiftPmReady)
        RawParagraph(
          '\n**Swift PM-ready:** This iOS or macOS plugin supports the Swift Package Manager. '
          'See https://docs.flutter.dev/to/spm for details.',
        ),
    ];

    // Determine score based on platforms, WASM, and Swift PM
    final int score;
    final ReportStatus status;

    if (officialTags.where((tag) => tag.startsWith('platform:')).isEmpty) {
      // No platforms supported
      score = 0;
      status = ReportStatus.failed;
    } else if ((hasWebPlatform && !isWasmReady) ||
        (needsToBeSwiftPmReady && !isSwiftPmReady)) {
      // Web platform but not WASM-ready OR iOS/macOS but not Swift PM-ready = partial score
      score = 10;
      status = ReportStatus.partial;
    } else {
      // Full platform support (WASM-ready web and/or Swift PM-ready iOS/macOS, or other platforms)
      score = 20;
      status = ReportStatus.passed;
    }

    final platforms = platformList(tags, tagNames);
    final description =
        'Supports ${officialTags.length} of '
        '${tagNames.length} possible platforms ($platforms)';
    subsection = Subsection(description, paragraphs, score, 20, status);
  } else {
    final toolErrorMessage = analysisResult.toolError?.message;
    subsection = Subsection(
      'Platform support detection failed',
      [
        Issue(
          'Could not determine supported platforms as package resolution failed.',
          suggestion:
              'Run `${flutterPackage ? 'flutter' : 'dart'} pub get` for more information.',
        ),
        if (toolErrorMessage != null)
          RawParagraph('```\n$toolErrorMessage\n```\n'),
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
    basePath: context.packageDir,
    subsections: [subsection],
    maxIssues: 20,
  );
}
