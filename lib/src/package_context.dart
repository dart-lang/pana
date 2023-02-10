// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:pana/src/tag/license_tags.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'code_problem.dart';
import 'download_utils.dart';
import 'internal_model.dart';
import 'license.dart';
import 'logging.dart';
import 'messages.dart' as messages;
import 'package_analyzer.dart' show InspectOptions;
import 'pkg_resolution.dart';
import 'pubspec.dart';
import 'pubspec_io.dart';
import 'references/pubspec_urls.dart';
import 'repository/check_repository.dart';
import 'screenshots.dart';
import 'sdk_env.dart';
import 'utils.dart' show copyDir, listFocusDirs, withTempDir;

/// Shared (intermediate) results between different packages or versions.
/// External systems that may be independent of the archive content may be
/// stored here, e.g. repository and URL verification.
class SharedAnalysisContext {
  final ToolEnvironment toolEnvironment;
  final InspectOptions options;
  final UrlChecker _urlChecker;

  SharedAnalysisContext({
    required this.toolEnvironment,
    InspectOptions? options,
    UrlChecker? urlChecker,
  })  : options = options ?? InspectOptions(),
        _urlChecker = urlChecker ?? UrlChecker();

  Future<UrlStatus> checkUrlStatus(String url) async {
    final cacheType = 'url';
    final cacheKey = url;
    final cachedData =
        await toolEnvironment.panaCache.readData(cacheType, cacheKey);
    if (cachedData != null) {
      return UrlStatus.fromJson(cachedData);
    }
    final status = await _urlChecker.checkStatus(url);
    await toolEnvironment.panaCache
        .writeData(cacheType, cacheKey, status.toJson());
    return status;
  }

  Future<VerifiedRepository?> verifyRepository(
    String package,
    String? repositoryOrHomepage,
  ) async {
    if (repositoryOrHomepage == null) {
      return null;
    }
    final cacheType = 'repository';
    final cacheKey = '$package/$repositoryOrHomepage';
    final cachedData =
        await toolEnvironment.panaCache.readData(cacheType, cacheKey);
    if (cachedData != null) {
      return VerifiedRepository.fromJson(cachedData);
    }
    final repository = await checkRepository(
      sharedContext: this,
      packageName: package,
      sourceUrl: repositoryOrHomepage,
    );
    if (repository != null) {
      await toolEnvironment.panaCache
          .writeData(cacheType, cacheKey, repository.toJson());
    }
    return repository;
  }
}

/// Calculates and stores the intermediate analysis and processing results that
/// are required for the final report.
class PackageContext {
  final SharedAnalysisContext sharedContext;
  final String packageDir;
  final errors = <String>[];
  final urlProblems = <String, String>{};

  Pubspec? _pubspec;
  bool? _dependenciesResolved;
  List<CodeProblem>? _codeProblems;

  PackageContext({
    required this.sharedContext,
    required this.packageDir,
  });

  ToolEnvironment get toolEnvironment => sharedContext.toolEnvironment;
  InspectOptions get options => sharedContext.options;

  late final Version currentSdkVersion =
      Version.parse(toolEnvironment.runtimeInfo.sdkVersion);

  Pubspec get pubspec {
    if (_pubspec != null) return _pubspec!;
    try {
      _pubspec = pubspecFromDir(packageDir);
    } catch (e, st) {
      log.info('Unable to read pubspec.yaml', e, st);
      rethrow;
    }
    return _pubspec!;
  }

  late final bool usesFlutter = pubspec.usesFlutter;

  Future<bool> resolveDependencies() async {
    if (_dependenciesResolved != null) {
      return _dependenciesResolved!;
    }

    String? stderr;
    try {
      await outdated;
      _dependenciesResolved = true;
      return true;
    } on ToolException catch (e) {
      stderr = e.stderr?.asString ?? e.message;
    } catch (e) {
      stderr = e.toString();
    }
    _dependenciesResolved = false;

    final errEntries =
        PubEntry.parse(stderr).where((e) => e.header == 'ERR').join('\n');
    final message = errEntries.isNotEmpty
        ? errEntries
        : stderr
            .split('\n')
            .map((e) => e.trim())
            .where((l) => l.isNotEmpty)
            .take(2)
            .join('\n');

    // 1: Version constraint issue with direct or transitive dependencies.
    //
    // 2: Code in a git repository could change or disappear.
    final isUserProblem = message.contains('version solving failed') || // 1
        pubspec.hasGitDependency || // 2
        message.contains('Git error.'); // 2

    if (!isUserProblem) {
      log.severe('`dart pub outdated` failed.\n$message'.trim());
    }

    // Note: calling `flutter pub pub` ensures we get the raw `pub` output.
    // TODO: get the actual command from [ToolException].
    final cmd = usesFlutter ? 'flutter pub outdated' : 'dart pub outdated';
    errors.add(message.isEmpty
        ? 'Running `$cmd` failed.'
        : 'Running `$cmd` failed with the following output:\n\n'
            '```\n$message\n```\n');

    return _dependenciesResolved!;
  }

  Future<List<CodeProblem>> staticAnalysis() async {
    if (_codeProblems != null) return _codeProblems!;
    try {
      log.info('Analyzing package...');
      _codeProblems = await _staticAnalysis(packageDir: packageDir);
      return _codeProblems!;
    } on ToolException catch (e) {
      errors.add(messages.runningDartanalyzerFailed(usesFlutter, e.message));
      rethrow;
    }
  }

  Future<List<CodeProblem>> _staticAnalysis({
    required String packageDir,
    bool useFutureSdk = false,
  }) async {
    final dirs = await listFocusDirs(packageDir);
    final problems = <CodeProblem>[];
    for (final dir in dirs) {
      final output = await toolEnvironment.runAnalyzer(
        packageDir,
        dir,
        usesFlutter,
        inspectOptions: options,
        useFutureSdk: useFutureSdk,
      );
      final list = LineSplitter.split(output)
          .map((s) => parseCodeProblem(s, projectDir: packageDir))
          .whereNotNull()
          .toSet()
          .toList();
      list.sort();
      problems.addAll(list);
    }
    return problems;
  }

  /// True if the configured future SDK analyzed the package without any error.
  late final isCompatibleWithFutureSdk = () async {
    return await withTempDir((tempPackageDir) async {
      try {
        log.info('Prepare package for future SDK compatibility check.');
        // Copy package to temp directory and delete the .dart_tool directory inside it.
        await copyDir(packageDir, tempPackageDir);
        final tempDartToolDir = Directory(p.join(tempPackageDir, '.dart_tool'));
        if (await tempDartToolDir.exists()) {
          await tempDartToolDir.delete(recursive: true);
        }

        log.info('Resolve dependencies with future SDK...');
        final pr = await toolEnvironment.runUpgrade(
          tempPackageDir,
          usesFlutter,
          useFutureSdk: true,
          retryCount: 1,
        );
        if (pr.wasError) {
          return false;
        }

        log.info('Analyzing package with future SDK...');
        final problems = await _staticAnalysis(
          packageDir: tempPackageDir,
          useFutureSdk: true,
        );
        return !problems.any((e) => e.isError);
      } on ToolException catch (_) {
        return false;
      }
    });
  }();

  late final Future<Outdated> outdated = toolEnvironment.runPubOutdated(
    packageDir,
    args: [
      '--json',
      '--up-to-date',
      '--no-dev-dependencies',
      '--no-dependency-overrides',
    ],
    usesFlutter: usesFlutter,
  );

  late final Future<List<ScreenshotResult>> screenshots =
      processAllScreenshots(pubspec.screenshots, packageDir);

  late final pubspecAllowsCurrentSdk = pubspec.dartSdkConstraint != null &&
      pubspec.dartSdkConstraint!.allows(currentSdkVersion);

  late final pubspecUrlsWithIssues = checkPubspecUrls(this);

  late final repository = sharedContext.verifyRepository(
      pubspec.name, pubspec.repositoryOrHomepage);

  late final licenses = detectLicenseInDir(packageDir);
  late final licenceTags = () async {
    return LicenseTags.fromLicenses(await licenses);
  }();
}
