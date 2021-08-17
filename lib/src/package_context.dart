// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

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
import 'utils.dart' show listFocusDirs, ProcessResultExt;

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

  Future<PkgResolution?> resolveDependencies() async {
    if (_pkgResolution != null) return _pkgResolution;
    final upgrade = await toolEnvironment.runUpgrade(packageDir, usesFlutter);

    if (upgrade.exitCode == 0) {
      try {
        _pkgResolution = createPkgResolution(pubspec, upgrade.asJoinedOutput,
            path: packageDir);
      } catch (e, stack) {
        log.severe('Problem with `dart pub upgrade`', e, stack);
        //(TODO)kevmoo - should add a helper that handles logging exceptions
        //  and writing to issues in one go.

        // Note: calling `flutter pub pub` ensures we get the raw `pub` output.
        final cmd = usesFlutter ? 'flutter pub upgrade' : 'dart pub upgrade';
        errors.add('Running `$cmd` failed with the following output:\n\n'
            '```\n$e\n```\n');
      }
    } else {
      String message;
      if (upgrade.exitCode > 0) {
        message = PubEntry.parse(upgrade.stderr as String)
            .where((e) => e.header == 'ERR')
            .join('\n');
      } else {
        message = LineSplitter.split(upgrade.stderr as String).first;
      }

      // 1: Version constraint issue with direct or transitive dependencies.
      //
      // 2: Code in a git repository could change or disappear.
      final isUserProblem = message.contains('version solving failed') || // 1
          pubspec.hasGitDependency || // 2
          message.contains('Git error.'); // 2

      if (!isUserProblem) {
        log.severe('`dart pub upgrade` failed.\n$message'.trim());
      }

      // Note: calling `flutter pub pub` ensures we get the raw `pub` output.
      final cmd = usesFlutter ? 'flutter pub upgrade' : 'dart pub upgrade';
      errors.add(message.isEmpty
          ? 'Running `$cmd` failed.'
          : 'Running `$cmd` failed with the following output:\n\n'
              '```\n$message\n```\n');
    }
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
            .where((e) => e != null)
            .toSet()
            .toList();
        list.sort();
      }
      _codeProblems = problems;
      return _codeProblems!;
    } on ToolException catch (e) {
      errors.add(messages.runningDartanalyzerFailed(usesFlutter, e.message));
      rethrow;
    }
  }

  bool get pubspecAllowsCurrentSdk =>
      pubspec.dartSdkConstraint != null &&
      pubspec.dartSdkConstraint!.allows(currentSdkVersion);
}
