// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'download_utils.dart';
import 'internal_model.dart';
import 'logging.dart';
import 'maintenance.dart';
import 'messages.dart';
import 'model.dart';
import 'package_context.dart';
import 'pubspec.dart';
import 'report/create_report.dart';
import 'sdk_env.dart';
import 'tag/pana_tags.dart';
import 'tag/tagger.dart';
import 'utils.dart';

class InspectOptions {
  final String? pubHostedUrl;
  final String? dartdocOutputDir;
  final int dartdocRetry;
  final Duration? dartdocTimeout;
  @Deprecated('Do not use, will be removed.')
  final bool isInternal;
  final int? lineLength;

  /// The analysis options (in yaml format) to use for the analysis.
  final String? analysisOptionsYaml;

  /// Whether pana should also access the remote repository specified in pubspec.yaml.
  final bool checkRemoteRepository;

  /// If specified, pana will analyze the package with future SDKs configured in
  /// [ToolEnvironment], and grant this tag if the analysis passes without errors.
  final String? futureSdkTag;

  InspectOptions({
    this.pubHostedUrl,
    this.dartdocOutputDir,
    this.dartdocRetry = 0,
    this.dartdocTimeout,
    @Deprecated('Do not use, will be removed.') this.isInternal = false,
    this.lineLength,
    this.analysisOptionsYaml,
    this.checkRemoteRepository = false,

    /// NOTE: this is an experimental option, do not rely on it.
    this.futureSdkTag,
  });
}

class PackageAnalyzer {
  final ToolEnvironment _toolEnv;
  final UrlChecker _urlChecker;

  PackageAnalyzer(this._toolEnv, {UrlChecker? urlChecker})
      : _urlChecker = urlChecker ?? UrlChecker();

  static Future<PackageAnalyzer> create({
    String? sdkDir,
    String? flutterDir,
    String? pubCacheDir,
    String? pubHostedUrl,
  }) async {
    return PackageAnalyzer(await ToolEnvironment.create(
        dartSdkDir: sdkDir,
        flutterSdkDir: flutterDir,
        pubCacheDir: pubCacheDir,
        environment: <String, String>{
          if (pubHostedUrl != null) 'PUB_HOSTED_URL': pubHostedUrl,
        }));
  }

  Future<Summary> inspectPackage(
    String package, {
    String? version,
    InspectOptions? options,
    Logger? logger,
    Future<void> Function(String filename, Uint8List data)? storeResource,
  }) async {
    options ??= InspectOptions();
    return withLogger(() async {
      return withTempDir((tempDir) async {
        await downloadPackage(package, version,
            destination: tempDir, pubHostedUrl: options!.pubHostedUrl);
        return await _inspect(tempDir, options, storeResource: storeResource);
      });
    }, logger: logger);
  }

  Future<Summary> inspectDir(String packageDir, {InspectOptions? options}) {
    options ??= InspectOptions();
    return withTempDir((tempDir) async {
      final rootDir = await _detectGitRoot(packageDir) ?? packageDir;
      await _copy(rootDir, tempDir);
      final relativeDir = path.relative(packageDir, from: rootDir);
      return await _inspect(path.join(tempDir, relativeDir), options!);
    });
  }

  Future<Summary> _inspect(
    String pkgDir,
    InspectOptions options, {
    Future<void> Function(String filename, Uint8List data)? storeResource,
  }) async {
    final tags = <String>{};
    final context = PackageContext(
      toolEnvironment: _toolEnv,
      packageDir: pkgDir,
      options: options,
      urlChecker: _urlChecker,
    );

    final dartFiles = <String>[];
    final fileList = listFiles(pkgDir, deleteBadExtracted: true);
    await for (final file in fileList) {
      final isInBin = path.isWithin('bin', file);
      final isInLib = path.isWithin('lib', file);
      final isDart = file.endsWith('.dart');
      if (isDart && (isInLib || isInBin)) {
        dartFiles.add(file);
      }
    }

    Pubspec? pubspec;
    try {
      pubspec = context.pubspec;
    } catch (e, st) {
      log.info('Unable to read pubspec.yaml', e, st);
      tags.add(PanaTags.hasError);
      return Summary(
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

    final dependenciesResolved = await context.resolveDependencies();
    if (dependenciesResolved && options.dartdocOutputDir != null) {
      for (var i = 0; i <= options.dartdocRetry; i++) {
        try {
          final r = await _toolEnv.dartdoc(
            pkgDir,
            options.dartdocOutputDir!,
            validateLinks: i == 0,
            timeout: options.dartdocTimeout,
          );
          if (!r.wasTimeout) {
            break;
          }
        } catch (e, st) {
          log.severe('Could not run dartdoc.', e, st);
        }
      }
    }

    if (dependenciesResolved) {
      List<CodeProblem>? analyzerItems;
      if (dartFiles.isNotEmpty) {
        try {
          analyzerItems = await context.staticAnalysis();
        } on ToolException catch (e) {
          context.errors
              .add(runningDartanalyzerFailed(context.usesFlutter, e.message));
        }
      } else {
        analyzerItems = <CodeProblem>[];
      }
      if (analyzerItems != null && !analyzerItems.any((item) => item.isError)) {
        final tagger = Tagger(pkgDir);
        final tags_ = <String>[];
        final explanations = <Explanation>[];
        // TODO: refactor these methods to return the tags+explanations
        tagger.sdkTags(tags_, explanations);
        tagger.platformTags(tags_, explanations);
        tagger.runtimeTags(tags_, explanations);
        tagger.flutterPluginTags(tags_, explanations);
        tagger.nullSafetyTags(tags_, explanations);
        // tags are exposed, explanations are ignored
        // TODO: use a single result object to derive tags + report
        tags.addAll(tags_);

        // When analysis was successful up until this point, also analyse with
        // future SDKs and award tag - if available.
        if (options.futureSdkTag != null &&
            await context.isCompatibleWithFutureSdk) {
          tags.add(options.futureSdkTag!);
        }
      } else {
        tags.add(PanaTags.hasError);
      }
    }

    final licenses = await context.licenses;
    tags.addAll((await context.licenceTags).tags);

    List<ProcessedScreenshot>? processedScreenshots = [];
    final screenshotResults = await context.screenshots;
    for (final r in screenshotResults) {
      if (r.problems.isEmpty) {
        final processedScreenshot = r.processedScreenshot!;
        processedScreenshots.add(processedScreenshot);

        if (storeResource != null) {
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

    String? errorMessage;
    if (context.errors.isNotEmpty) {
      errorMessage = context.errors.map((e) => e.trim()).join('\n\n');
    }
    return Summary(
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
      report: await createReport(context),
      result: await _createAnalysisResult(context),
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
  final pr = await runProc(
    ['git', 'rev-parse', '--show-toplevel'],
    workingDirectory: packageDir,
  );
  if (pr.exitCode == 0) {
    return pr.stdout.asString.trim();
  }
  return null;
}

Future<void> _copy(String from, String to) async {
  await for (final fse in Directory(from).list(recursive: true)) {
    if (fse is File) {
      final relativePath = path.relative(fse.path, from: from);
      final newFile = File(path.join(to, relativePath));
      await newFile.parent.create(recursive: true);
      await fse.copy(newFile.path);
    } else if (fse is Link) {
      final relativePath = path.relative(fse.path, from: from);
      final linkTarget = await fse.target();
      final newLink = Link(path.join(to, relativePath));
      await newLink.parent.create(recursive: true);
      await newLink.create(linkTarget);
    }
  }
}

Future<AnalysisResult> _createAnalysisResult(PackageContext context) async {
  final pubspecUrls = await context.pubspecUrlsWithIssues;
  final repoVerification = await context.repository;
  final repository = repoVerification?.repository;
  final fundingUrls =
      pubspecUrls.funding.map((e) => e.verifiedUrl).whereNotNull().toList();
  return AnalysisResult(
    homepageUrl: pubspecUrls.homepage.verifiedUrl,
    repositoryUrl: pubspecUrls.repository.verifiedUrl,
    issueTrackerUrl: pubspecUrls.issueTracker.verifiedUrl,
    documentationUrl: pubspecUrls.documentation.verifiedUrl,
    fundingUrls: fundingUrls.isEmpty ? null : fundingUrls,
    repository: repository,
    contributingUrl: repoVerification?.contributingUrl,
  );
}
