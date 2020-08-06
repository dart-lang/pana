// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:pana/src/create_report.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import 'code_problem.dart';
import 'download_utils.dart';
import 'license.dart';
import 'logging.dart';
import 'maintenance.dart';
import 'messages.dart' as messages;
import 'model.dart';
import 'pkg_resolution.dart';
import 'pubspec.dart';
import 'pubspec_io.dart';
import 'sdk_env.dart';
import 'tag_detection.dart';
import 'utils.dart';

class InspectOptions {
  final String pubHostedUrl;
  final String dartdocOutputDir;
  final int dartdocRetry;
  final Duration dartdocTimeout;
  final bool isInternal;
  final int lineLength;
  final String analysisOptionsUri;

  InspectOptions({
    this.pubHostedUrl,
    this.dartdocOutputDir,
    this.dartdocRetry = 0,
    this.dartdocTimeout,
    this.isInternal = false,
    this.lineLength,
    this.analysisOptionsUri,
  });
}

class PackageAnalyzer {
  final ToolEnvironment _toolEnv;
  final UrlChecker _urlChecker;

  PackageAnalyzer(this._toolEnv, {UrlChecker urlChecker})
      : _urlChecker = urlChecker ?? UrlChecker();

  static Future<PackageAnalyzer> create(
      {String sdkDir, String flutterDir, String pubCacheDir}) async {
    return PackageAnalyzer(await ToolEnvironment.create(
        dartSdkDir: sdkDir,
        flutterSdkDir: flutterDir,
        pubCacheDir: pubCacheDir));
  }

  Future<Summary> inspectPackage(
    String package, {
    String version,
    InspectOptions options,
    Logger logger,
  }) async {
    options ??= InspectOptions();
    return withLogger(() async {
      log.info('Downloading package $package ${version ?? 'latest'}');
      return withTempDir((tempDir) async {
        await downloadPackage(package, version,
            destination: tempDir, pubHostedUrl: options.pubHostedUrl);
        return await _inspect(tempDir, options);
      });
    }, logger: logger);
  }

  Future<Summary> inspectDir(String packageDir, {InspectOptions options}) {
    options ??= InspectOptions();
    return _inspect(packageDir, options);
  }

  Future<Summary> _inspect(String pkgDir, InspectOptions options) async {
    final errors = <String>[];

    var dartFiles = await listFiles(
      pkgDir,
      endsWith: '.dart',
      deleteBadExtracted: true,
    )
        .where(
            (file) => path.isWithin('bin', file) || path.isWithin('lib', file))
        .toList();

    log.info('Parsing pubspec.yaml...');
    Pubspec pubspec;
    try {
      pubspec = pubspecFromDir(pkgDir);
    } catch (e, st) {
      log.info('Unable to read pubspec.yaml', e, st);
      return Summary(
        runtimeInfo: _toolEnv.runtimeInfo,
        packageName: null,
        packageVersion: null,
        pubspec: pubspec,
        pkgResolution: null,
        licenseFile: null,
        tags: null,
        report: null,
        errorMessage: pubspecParseError(e),
      );
    }
    if (pubspec.hasUnknownSdks) {
      errors.add('The following unknown SDKs are in `pubspec.yaml`:\n'
          '  `${pubspec.unknownSdks}`.\n\n'
          '`pana` doesn’t recognize them; please remove the `sdk` entry or '
          '[report the issue](https://github.com/dart-lang/pana/issues).');
    }

    final usesFlutter = pubspec.usesFlutter;
    final upgrade = await _toolEnv.runUpgrade(pkgDir, usesFlutter);

    PkgResolution pkgResolution;
    if (upgrade.exitCode == 0) {
      try {
        pkgResolution = createPkgResolution(pubspec, upgrade.stdout as String,
            path: pkgDir);
      } catch (e, stack) {
        log.severe('Problem with pub upgrade', e, stack);
        //(TODO)kevmoo - should add a helper that handles logging exceptions
        //  and writing to issues in one go.

        // Note: calling `flutter pub pub` ensures we get the raw `pub` output.
        final cmd = usesFlutter ? 'flutter pub upgrade' : 'pub upgrade';
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
        log.severe('`pub upgrade` failed.\n$message'.trim());
      }

      // Note: calling `flutter pub pub` ensures we get the raw `pub` output.
      final cmd = usesFlutter ? 'flutter pub upgrade' : 'pub upgrade';
      errors.add(message.isEmpty
          ? 'Running `$cmd` failed.'
          : 'Running `$cmd` failed with the following output:\n\n'
              '```\n$message\n```\n');
    }

    List<CodeProblem> analyzerItems;

    if (pkgResolution != null && options.dartdocOutputDir != null) {
      for (var i = 0; i <= options.dartdocRetry; i++) {
        try {
          final r = await _toolEnv.dartdoc(
            pkgDir,
            options.dartdocOutputDir,
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

    final tags = <String>[];
    if (pkgResolution != null) {
      if (dartFiles.isNotEmpty) {
        try {
          analyzerItems = await _pkgAnalyze(pkgDir, usesFlutter, options);
        } on ToolException catch (e) {
          errors
              .add(messages.runningDartanalyzerFailed(usesFlutter, e.message));
        }
      } else {
        analyzerItems = <CodeProblem>[];
      }

      if (analyzerItems != null && !analyzerItems.any((item) => item.isError)) {
        final tagger = Tagger(pkgDir);
        final explanations = <Explanation>[];
        tagger.sdkTags(tags, explanations);
        tagger.flutterPlatformTags(tags, explanations);
        tagger.runtimeTags(tags, explanations);
        if (_sdkSupportsNullSafety) {
          tagger.nullSafetyTags(tags, explanations);
        }
      }
    }

    final licenseFile = await detectLicenseInDir(pkgDir);
    final licenseUrl = await getLicenseUrl(
        _urlChecker, pubspec.repository ?? pubspec.homepage, licenseFile);

    final errorMessage =
        errors.isEmpty ? null : errors.map((e) => e.trim()).join('\n\n');
    return Summary(
      runtimeInfo: _toolEnv.runtimeInfo,
      packageName: pubspec.name,
      packageVersion: pubspec.version,
      pubspec: pubspec,
      pkgResolution: pkgResolution,
      licenseFile: licenseFile.change(url: licenseUrl),
      tags: tags,
      report: await createReport(options, pkgDir, _toolEnv),
      errorMessage: errorMessage,
    );
  }

  Future<List<CodeProblem>> _pkgAnalyze(
      String pkgPath, bool usesFlutter, InspectOptions inspectOptions) async {
    log.info('Analyzing package...');
    final dirs = await listFocusDirs(pkgPath);
    if (dirs.isEmpty) {
      return null;
    }
    final output = await _toolEnv.runAnalyzer(pkgPath, dirs, usesFlutter,
        inspectOptions: inspectOptions);
    final list = LineSplitter.split(output)
        .map((s) => parseCodeProblem(s, projectDir: pkgPath))
        .where((e) => e != null)
        .toSet()
        .toList();
    list.sort();
    return list;
  }
}

final _sdkVersion = Version.parse(Platform.version.split(' ').first);
final _sdkSupportsNullSafety = _sdkVersion >= Version.parse('2.10.0');
