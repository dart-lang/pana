// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:pana/src/tag/license_tags.dart';
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
import 'utils.dart' show listFocusDirs;

/// Calculates and stores the intermediate analysis and processing results that
/// are required for the final report.
class PackageContext {
  final ToolEnvironment toolEnvironment;
  final String packageDir;
  final InspectOptions options;
  final UrlChecker urlChecker;
  final errors = <String>[];
  final urlProblems = <String, String>{};

  Pubspec? _pubspec;
  bool? _dependenciesResolved;
  List<CodeProblem>? _codeProblems;

  PackageContext({
    required this.toolEnvironment,
    required this.packageDir,
    required this.options,
    UrlChecker? urlChecker,
  }) : urlChecker = urlChecker ?? UrlChecker();

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
    log.info('Analyzing package...');
    try {
      final dirs = await listFocusDirs(packageDir);
      final problems = <CodeProblem>[];
      for (final dir in dirs) {
        final output = await toolEnvironment
            .runAnalyzer(packageDir, dir, usesFlutter, inspectOptions: options);
        final list = LineSplitter.split(output)
            .map((s) => parseCodeProblem(s, projectDir: packageDir))
            .whereNotNull()
            .toSet()
            .toList();
        list.sort();
        problems.addAll(list);
      }
      _codeProblems = problems;
      return _codeProblems!;
    } on ToolException catch (e) {
      errors.add(messages.runningDartanalyzerFailed(usesFlutter, e.message));
      rethrow;
    }
  }

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

  late final repository = checkRepository(this);

  late final licenses = detectLicenseInDir(packageDir);
  late final licenceTags = () async {
    return LicenseTags.fromLicenses(await licenses);
  }();
}
