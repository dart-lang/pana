// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'download_utils.dart';
import 'logging.dart';
import 'maintenance.dart';
import 'model.dart';
import 'package_context.dart';
import 'pubspec.dart';
import 'report/create_report.dart';
import 'sdk_env.dart';
import 'tag/pana_tags.dart';
import 'tool/git_tool.dart';
import 'utils.dart';

class InspectOptions {
  /// The PUB_HOSTED_URL to use for the package download and dependency analysis.
  final String? pubHostedUrl;

  /// The cache directory for cross-analysis (shared) pana results.
  final String? panaCacheDir;

  /// The output directory to copy the generated docs. When not specified,
  /// the generated docs will be discarded.
  final String? dartdocOutputDir;

  /// The output directory to store the extracted/derived resources like screenshots.
  /// When not specified, the resources will be discarded.
  final String? resourcesOutputDir;

  /// The total time budget allocated for the full analysis. `pana` may not be
  /// able to finish the analysis within this time, but some parts will be
  /// running with reduced timeouts in the attempt to complete the analysis
  /// with partial results.
  final Duration? totalTimeout;

  /// The timeout to use when running `dartdoc` on the package.
  ///
  /// When [totalTimeout] is also specified, the lower of
  /// [dartdocTimeout] and the remaining budget will be used.
  final Duration dartdocTimeout;

  /// The line length parameter to be used for dart format checks.
  final int? lineLength;

  InspectOptions({
    this.pubHostedUrl,
    this.panaCacheDir,
    this.dartdocOutputDir,
    this.resourcesOutputDir,
    this.totalTimeout,
    Duration? dartdocTimeout,
    this.lineLength,
  }) : dartdocTimeout = dartdocTimeout ?? const Duration(minutes: 5);
}

class PackageAnalyzer {
  final ToolEnvironment _toolEnv;
  final UrlChecker _urlChecker;

  PackageAnalyzer(this._toolEnv, {UrlChecker? urlChecker})
      : _urlChecker = urlChecker ?? UrlChecker();

  Future<Summary> inspectPackage(
    String package, {
    String? version,
    InspectOptions? options,
    Logger? logger,
  }) async {
    final sharedContext = _createSharedContext(options: options);
    return withLogger(() async {
      return withTempDir((tempDir) async {
        await downloadPackage(
          package,
          version,
          destination: tempDir,
          pubHostedUrl: options?.pubHostedUrl,
        );
        return await _inspect(sharedContext, tempDir);
      });
    }, logger: logger);
  }

  Future<Summary> inspectDir(
    String packageDir, {
    InspectOptions? options,
    Logger? logger,
  }) {
    final sharedContext = _createSharedContext(options: options);
    return withLogger(
      logger: logger,
      () async {
        return withTempDir((tempDir) async {
          final rootDir = await _detectGitRoot(packageDir) ?? packageDir;
          await copyDir(rootDir, tempDir);
          final relativeDir = path.relative(packageDir, from: rootDir);
          return await _inspect(sharedContext, path.join(tempDir, relativeDir));
        });
      },
    );
  }

  SharedAnalysisContext _createSharedContext({
    required InspectOptions? options,
  }) =>
      SharedAnalysisContext(
        toolEnvironment: _toolEnv,
        options: options ?? InspectOptions(),
        urlChecker: _urlChecker,
      );

  Future<Summary> _inspect(
      SharedAnalysisContext sharedContext, String pkgDir) async {
    final tags = <String>{};
    final context = PackageContext(
      sharedContext: sharedContext,
      packageDir: pkgDir,
    );

    Pubspec? pubspec;
    try {
      pubspec = context.pubspec;
    } catch (e, st) {
      log.info('Unable to read pubspec.yaml', e, st);
      tags.add(PanaTags.hasError);
      return Summary(
        createdAt: DateTime.now().toUtc(),
        runtimeInfo: _toolEnv.runtimeInfo,
        packageName: null,
        packageVersion: null,
        pubspec: pubspec,
        allDependencies: null,
        licenseFile: null,
        tags: tags.toList(),
        report: null,
        errorMessage: pubspecParseError(e),
      );
    }
    if (pubspec.hasUnknownSdks) {
      context.errors.add('The following unknown SDKs are in `pubspec.yaml`:\n'
          '  `${pubspec.unknownSdks}`.\n\n'
          '`pana` doesn’t recognize them; please remove the `sdk` entry or '
          '[report the issue](https://github.com/dart-lang/pana/issues).');
    }

    final tr = await context.staticAnalysis;
    tags.addAll(tr.tags);

    final licenses = await context.licenses;
    tags.addAll((await context.licenceTags).tags);

    if ((await context.executablesInBinDirectory).isNotEmpty) {
      tags.add(PanaTags.hasExecutable);
    }

    List<ProcessedScreenshot>? processedScreenshots = [];
    final screenshotResults = await context.screenshots;
    for (final r in screenshotResults) {
      if (r.problems.isEmpty) {
        final processedScreenshot = r.processedScreenshot!;
        processedScreenshots.add(processedScreenshot);

        final resourcesOutputDir = context.options.resourcesOutputDir;
        if (resourcesOutputDir != null) {
          Future<void> storeResource(
              String resourcePath, Uint8List bytes) async {
            final f = File(path.join(resourcesOutputDir, resourcePath));
            await f.parent.create(recursive: true);
            await f.writeAsBytes(bytes);
          }

          await storeResource(processedScreenshot.webpImage, r.webpImageBytes!);
          await storeResource(
              processedScreenshot.webp100Thumbnail, r.webp100ThumbnailBytes!);
          await storeResource(
              processedScreenshot.png100Thumbnail, r.png100ThumbnailBytes!);
          await storeResource(
              processedScreenshot.webp190Thumbnail, r.webp190ThumbnailBytes!);
          await storeResource(
              processedScreenshot.png190Thumbnail, r.png190ThumbnailBytes!);
        }
      }
    }
    if (processedScreenshots.isNotEmpty) {
      tags.add(PanaTags.hasScreenshot);
    }

    for (final topic in pubspec.topics) {
      tags.add(PanaTags.topic(topic));
    }

    final allDependencies = <String>{
      ...pubspec.dependencies.keys,
      ...pubspec.devDependencies.keys,
    };
    // add transient dependencies
    try {
      final outdated = await context.outdated;
      allDependencies.addAll(outdated.packages.map((e) => e.package));
    } catch (_) {
      // do not update allDependencies.
    }
    // trivial filter to remove not supported dependencies
    allDependencies
        .removeWhere((pkg) => pkg.contains('-') || pkg.contains('.'));

    String? errorMessage;
    if (context.errors.isNotEmpty) {
      errorMessage = context.errors.map((e) => e.trim()).join('\n\n');
    }
    final report = await createReport(context);
    return Summary(
      createdAt: DateTime.now(),
      runtimeInfo: _toolEnv.runtimeInfo,
      packageName: pubspec.name,
      packageVersion: pubspec.version,
      pubspec: pubspec,
      allDependencies: allDependencies.toList()..sort(),
      licenseFile: licenses.isEmpty
          ? null
          : LicenseFile(licenses.first.path, licenses.first.spdxIdentifier),
      licenses: licenses,
      tags: tags.toList(),
      report: report,
      result: await _createAnalysisResult(context, report),
      urlProblems: context.urlProblems.entries
          .map((e) => UrlProblem(url: e.key, problem: e.value))
          .toList()
        ..sort((a, b) => a.url.compareTo(b.url)),
      errorMessage: errorMessage,
      screenshots: processedScreenshots,
    );
  }
}

Future<String?> _detectGitRoot(String packageDir) async {
  try {
    final pr = await runGitIsolated(
      ['rev-parse', '--show-toplevel'],
      workingDirectory: packageDir,
    );
    return pr.stdout.asString.trim();
  } on GitToolException catch (_) {
    // not in a git directory (or git is broken) - ignore exception
  }
  return null;
}

Future<AnalysisResult> _createAnalysisResult(
    PackageContext context, Report report) async {
  final pubspecUrls = await context.pubspecUrlsWithIssues;
  final repoVerification = await context.repository;
  final repository = repoVerification.repository;
  final fundingUrls =
      pubspecUrls.funding.map((e) => e.acceptedUrl).nonNulls.toList();
  return AnalysisResult(
    homepageUrl: pubspecUrls.homepage.acceptedUrl,
    repositoryUrl: pubspecUrls.repository.acceptedUrl,
    issueTrackerUrl: pubspecUrls.issueTracker.acceptedUrl,
    documentationUrl: pubspecUrls.documentation.acceptedUrl,
    fundingUrls: fundingUrls.isEmpty ? null : fundingUrls,
    repositoryStatus: repoVerification.status,
    repository: repository,
    contributingUrl: repoVerification.contributingUrl,
    licenses: await context.licenses,
    grantedPoints: report.grantedPoints,
    maxPoints: report.maxPoints,
  );
}
