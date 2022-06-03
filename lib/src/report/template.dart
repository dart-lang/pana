// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart' show GitDependency;

import '../markdown_content.dart';
import '../model.dart';
import '../package_context.dart';
import '../utils.dart';

import '_common.dart';

const _pluginDocsUrl =
    'https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin';

Future<ReportSection> followsTemplate(PackageContext context) async {
  final packageDir = context.packageDir;
  final pubspec = context.pubspec;

  List<Issue> findFileSizeIssues(File file,
      {int limitInKB = 128, String? missingSuggestion}) {
    final length = file.lengthSync();
    final lengthInKB = length / 1024.0;
    return [
      if (length == 0)
        Issue('${p.relative(file.path, from: packageDir)} is empty.',
            suggestion: missingSuggestion),
      if (lengthInKB > limitInKB)
        Issue(
          '${p.relative(file.path, from: packageDir)} too large.',
          suggestion: 'Try to keep the file size under ${limitInKB}k.',
        )
    ];
  }

  /// Analyze a markdown file and return suggestions.
  Future<List<Issue>> findMarkdownIssues(File file) async {
    final issues = <Issue>[];
    final filename = p.basename(file.path);
    final analysis = await scanMarkdownFileContent(file);
    Future<void> findLinkIssues(List<Link> links, String linkType) async {
      final checked = await checkLinks(links);
      // TODO: warn about relative image URLs
      // TODO: warn about relative links
      // TODO: consider checking whether the URL exists and returns HTTP 200.

      if (checked.unparsed.isNotEmpty) {
        final count = checked.unparsed.length;
        final first = checked.unparsed.first;
        final s = count == 1 ? '' : 's';
        issues.add(Issue(
            'Links in `$filename` should be well formed '
            'Unable to parse $count image link$s.',
            span: first.span));
      }
      if (checked.insecure.isNotEmpty) {
        final count = checked.insecure.length;
        final first = checked.insecure.first;
        final sAre = count == 1 ? ' is' : 's are';
        issues.add(Issue(
            'Links in `$filename` should be secure. $count $linkType$sAre insecure.',
            suggestion: 'Use `https` URLs instead.',
            span: first.span));
      }
    }

    await findLinkIssues(analysis.links, 'link');
    await findLinkIssues(analysis.images, 'image link');
    if (analysis.isMalformedUtf8) {
      issues.add(Issue(
        '`$filename` is not a valid UTF-8 file.',
        suggestion:
            'The content of `$filename` in your package should contain valid UTF-8 characters.',
      ));
    }
    if (analysis.nonAsciiRatio > 0.2) {
      issues.add(Issue(
        '`$filename` contains too many non-ASCII characters.',
        suggestion:
            'The site uses English as its primary language. The content of '
            '`$filename` in your package should primarily contain characters used in English.',
      ));
    }

    return issues;
  }

  Future<Subsection> checkPubspec() async {
    final issues = <Issue>[];
    if (pubspec.hasUnknownSdks) {
      issues.add(Issue('Unknown SDKs in `pubspec.yaml`.',
          span: tryGetSpanFromYamlMap(
              pubspec.environment, pubspec.unknownSdks.first),
          suggestion: 'The following unknown SDKs are in `pubspec.yaml`:\n'
              '`${pubspec.unknownSdks}`.\n\n'
              '`pana` doesn’t recognize them; please remove the `sdk` entry.'));
    }

    final gitDependencies =
        pubspec.dependencies.entries.where((e) => e.value is GitDependency);
    if (gitDependencies.isNotEmpty) {
      issues.add(Issue(
        'The package has a git dependency.',
        span: tryGetSpanFromYamlMap(pubspec.originalYaml['dependencies'] as Map,
            gitDependencies.first.key),
        suggestion: "The pub site doesn't allow git dependencies.",
      ));
    }

    if (pubspec.usesOldFlutterPluginFormat) {
      issues.add(
        Issue(
          'Flutter plugin descriptor uses old format.',
          span: tryGetSpanFromYamlMap(
              pubspec.originalYaml['flutter'] as Map, 'plugin'),
          suggestion:
              'The flutter.plugin.{androidPackage,iosPrefix,pluginClass} keys are '
              'deprecated. Consider using the flutter.plugin.platforms key '
              'introduced in Flutter 1.10.0\n\n See $_pluginDocsUrl',
        ),
      );
    }

    if (pubspec.shouldWarnDart2Constraint) {
      issues.add(
        Issue(
          "Sdk-constraint doesn't allow future stable dart 2.x releases",
          span: tryGetSpanFromYamlMap(
            pubspec.environment,
            'sdk',
          ),
        ),
      );
    }

    // Checking the length of description.
    final description = pubspec.description?.trim();
    final span = tryGetSpanFromYamlMap(pubspec.originalYaml, 'description');
    if (description == null || description.isEmpty) {
      issues.add(
        Issue(
          'Add `description` in `pubspec.yaml`.',
          span: span,
          suggestion:
              'The description gives users information about the features of your '
              'package and why it is relevant to their query. We recommend a '
              'description length of 60 to 180 characters.',
        ),
      );
    } else if (description.length < 60) {
      issues.add(
        Issue('The package description is too short.',
            span: span,
            suggestion:
                'Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 '
                'characters to describe the package, what it does, and its target use case.'),
      );
    } else if (description.length > 180) {
      issues.add(
        Issue('The package description is too long.',
            span: span,
            suggestion:
                'Search engines display only the first part of the description. '
                "Try to keep the value of the `description` field in your package's "
                '`pubspec.yaml` file between 60 and 180 characters.'),
      );
    }

    // characters in description
    if (nonAsciiRuneRatio(description) > 0.1) {
      issues.add(Issue(
        'The package description contains too many non-ASCII characters.',
        span: span,
        suggestion:
            'The site uses English as its primary language. The content of the '
            "`description` field in your package's `pubspec.yaml` should "
            'primarily contain characters used in English.',
      ));
    }

    final pubspecUrls = await context.pubspecUrlsWithIssues;
    issues.addAll(pubspecUrls.issues);

    final repository = await context.repository;
    if (repository?.verificationFailure != null) {
      issues.add(Issue('Failed to verify repository URL.',
          suggestion:
              'Please provide a valid [`repository`](https://dart.dev/tools/pub/pubspec#repository) URL in `pubspec.yaml`, such that:\n\n'
              ' * `repository` can be cloned,\n'
              ' * a clone of the repository contains a `pubspec.yaml`, which:,\n'
              '    * contains `name: ${pubspec.name}`,\n'
              '    * contains a `version` property, and,\n'
              '    * does not contain a `publish_to` property.\n\n'
              '${repository!.verificationFailure}'));
    }

    issues.addAll(findFileSizeIssues(File(p.join(packageDir, 'pubspec.yaml')),
        limitInKB: 32));

    final status = issues.isEmpty ? ReportStatus.passed : ReportStatus.failed;
    final points = issues.isEmpty ? 10 : 0;
    return Subsection(
      'Provide a valid `pubspec.yaml`',
      issues,
      points,
      10,
      status,
    );
  }

  Future<Subsection> checkAsset(
    String filename,
    String missingSuggestion,
  ) async {
    final fullPath = p.join(packageDir, filename);
    final file = File(fullPath);
    final issues = <Issue>[];

    if (!file.existsSync()) {
      issues.add(
        Issue('No `$filename` found.', suggestion: missingSuggestion),
      );
    } else {
      issues.addAll(
          findFileSizeIssues(file, missingSuggestion: missingSuggestion));
      issues.addAll(await findMarkdownIssues(file));
    }
    final status = issues.isEmpty ? ReportStatus.passed : ReportStatus.failed;
    final points = issues.isEmpty ? 5 : 0;
    return Subsection(
      'Provide a valid `$filename`',
      issues,
      points,
      5,
      status,
    );
  }

  final readmeSubsection = await checkAsset(
    'README.md',
    'The `README.md` file should inform others about your project, what it does, and how they can use it. '
        'See: the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/README.md) generated by `stagehand`.',
  );
  final changelogSubsection = await checkAsset(
    'CHANGELOG.md',
    'Changelog entries help developers follow the progress of your package. '
        'See the [example](https://raw.githubusercontent.com/dart-lang/stagehand/master/templates/package-simple/CHANGELOG.md) generated by `stagehand`.',
  );
  final pubspecSection = await checkPubspec();
  final subsections = [pubspecSection, readmeSubsection, changelogSubsection];
  return makeSection(
    id: ReportSectionId.convention,
    title: 'Follow Dart file conventions',
    maxPoints: 20,
    subsections: subsections,
    basePath: packageDir,
    maxIssues: 10,
  );
}
