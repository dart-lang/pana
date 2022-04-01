// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:pana/src/screenshots.dart';
import 'package:pub_semver/pub_semver.dart';

import 'code_problem.dart';
import 'download_utils.dart';
import 'internal_model.dart';
import 'logging.dart';
import 'messages.dart' as messages;
import 'package_analyzer.dart' show InspectOptions;
import 'pkg_resolution.dart';
import 'pubspec.dart';
import 'pubspec_io.dart';
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

  Version? _currentSdkVersion;
  Pubspec? _pubspec;
  bool? _usesFlutter;
  PkgResolution? _pkgResolution;
  List<CodeProblem>? _codeProblems;

  List<ScreenshotResult>? _screenshotResults;

  PackageContext({
    required this.toolEnvironment,
    required this.packageDir,
    required this.options,
    UrlChecker? urlChecker,
  }) : urlChecker = urlChecker ?? UrlChecker();

  Version get currentSdkVersion => _currentSdkVersion ??=
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

  bool get usesFlutter => _usesFlutter ??= pubspec.usesFlutter;

  late final Future<Outdated> outdatedOutput = toolEnvironment.runPubOutdated(
    packageDir,
    args: [
      '--json',
      '--show-all',
      '--no-dev-dependencies',
      '--no-dependency-overrides',
    ],
    usesFlutter: usesFlutter,
  );

Future<PkgResolution?> resolveDependencies() async {
    if (_pkgResolution != null) return _pkgResolution;
    final Outdated outdated;
    try {
      outdated = await outdatedOutput;
    } on ToolException catch (e) {
      errors.add(e.message);
      return null;
    }
    _pkgResolution = createPkgResolution(
      pubspec,
      outdated,
      path: packageDir,
    );

    return _pkgResolution;
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

  Future<List<ScreenshotResult>> processScreenshots() async {
    return _screenshotResults ??=
        await processAllScreenshots(pubspec.screenshots, packageDir);
  }

  bool get pubspecAllowsCurrentSdk =>
      pubspec.dartSdkConstraint != null &&
      pubspec.dartSdkConstraint!.allows(currentSdkVersion);
}
