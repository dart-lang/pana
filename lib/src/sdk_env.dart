// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_util.dart' as cli;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'analysis_options.dart';
import 'logging.dart';
import 'model.dart' show PanaRuntimeInfo;
import 'package_analyzer.dart' show InspectOptions;
import 'pubspec_io.dart';
import 'utils.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'version.dart';

const _dartfmtTimeout = Duration(minutes: 5);

class ToolEnvironment {
  final String? dartSdkDir;
  final String? flutterSdkDir;
  final String? pubCacheDir;
  final List<String> _dartCmd;
  final List<String> _pubCmd;
  final List<String> _dartAnalyzerCmd;
  final List<String> _dartfmtCmd;
  final List<String> _dartdocCmd;
  final List<String> _flutterCmd;
  // TODO: remove this after flutter analyze gets machine-readable output.
  // https://github.com/flutter/flutter/issues/23664
  final List<String> _flutterDartAnalyzerCmd;
  final Map<String, String> _environment;
  PanaRuntimeInfo? _runtimeInfo;
  final bool _useGlobalDartdoc;

  ToolEnvironment._(
    this.dartSdkDir,
    this.flutterSdkDir,
    this.pubCacheDir,
    this._dartCmd,
    this._pubCmd,
    this._dartAnalyzerCmd,
    this._dartfmtCmd,
    this._dartdocCmd,
    this._flutterCmd,
    this._flutterDartAnalyzerCmd,
    this._environment,
    this._useGlobalDartdoc,
  );

  ToolEnvironment.fake({
    this.dartSdkDir,
    this.flutterSdkDir,
    this.pubCacheDir,
    List<String> dartCmd = const <String>[],
    List<String> pubCmd = const <String>[],
    List<String> dartAnalyzerCmd = const <String>[],
    List<String> dartfmtCmd = const <String>[],
    List<String> dartdocCmd = const <String>[],
    List<String> flutterCmd = const <String>[],
    List<String> flutterDartAnalyzerCmd = const <String>[],
    Map<String, String> environment = const <String, String>{},
    bool useGlobalDartdoc = false,
    required PanaRuntimeInfo runtimeInfo,
  })   : _dartCmd = dartCmd,
        _pubCmd = pubCmd,
        _dartAnalyzerCmd = dartAnalyzerCmd,
        _dartfmtCmd = dartfmtCmd,
        _dartdocCmd = dartdocCmd,
        _flutterCmd = flutterCmd,
        _flutterDartAnalyzerCmd = flutterDartAnalyzerCmd,
        _environment = environment,
        _useGlobalDartdoc = useGlobalDartdoc,
        _runtimeInfo = runtimeInfo;

  PanaRuntimeInfo get runtimeInfo => _runtimeInfo!;

  Future _init() async {
    final dartVersionResult = _handleProcessErrors(
        await runProc([..._dartCmd, '--version'], environment: _environment));
    final dartVersionString = dartVersionResult.stderr.toString().trim();
    final dartSdkInfo = DartSdkInfo.parse(dartVersionString);
    Map<String, dynamic>? flutterVersions;
    try {
      flutterVersions = await getFlutterVersion();
    } catch (e) {
      log.warning('Unable to detect Flutter version.', e);
    }
    _runtimeInfo = PanaRuntimeInfo(
      panaVersion: packageVersion,
      sdkVersion: dartSdkInfo.version.toString(),
      flutterVersions: flutterVersions,
    );
  }

  static Future<ToolEnvironment> create({
    String? dartSdkDir,
    String? flutterSdkDir,
    String? pubCacheDir,
    Map<String, String>? environment,
    bool useGlobalDartdoc = false,
  }) async {
    Future<String?> resolve(String? dir) async {
      if (dir == null) return null;
      return Directory(dir).resolveSymbolicLinks();
    }

    dartSdkDir ??= cli.getSdkPath();
    final resolvedDartSdk = await resolve(dartSdkDir);
    final resolvedFlutterSdk = await resolve(flutterSdkDir);
    final resolvedPubCache = await resolve(pubCacheDir);
    final env = <String, String>{};
    env.addAll(environment ?? const {});

    if (resolvedPubCache != null) {
      env[_pubCacheKey] = resolvedPubCache;
    }

    final pubEnvValues = <String>[];
    final origPubEnvValue = Platform.environment[_pubEnvironmentKey] ?? '';
    pubEnvValues.addAll(origPubEnvValue
        .split(':')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty));
    pubEnvValues.add('bot.pkg_pana');
    env[_pubEnvironmentKey] = pubEnvValues.join(':');

    // Flutter stores its internal SDK in its bin/cache/dart-sdk directory.
    // We can use that directory only if Flutter SDK path was specified,
    // TODO: remove this after flutter analyze gets machine-readable output.
    // https://github.com/flutter/flutter/issues/23664
    final flutterDartSdkDir = resolvedFlutterSdk == null
        ? resolvedDartSdk
        : p.join(resolvedFlutterSdk, 'bin', 'cache', 'dart-sdk');
    if (flutterDartSdkDir == null) {
      log.warning(
          'Flutter SDK path was not specified, pana will use the default '
          'Dart SDK to run `dart analyze` on Flutter packages.');
    }

    final toolEnv = ToolEnvironment._(
      resolvedDartSdk,
      resolvedFlutterSdk,
      resolvedPubCache,
      [_join(resolvedDartSdk, 'bin', 'dart')],
      [_join(resolvedDartSdk, 'bin', 'dart'), 'pub'],
      [_join(resolvedDartSdk, 'bin', 'dart'), 'analyze'],
      [_join(resolvedDartSdk, 'bin', 'dartfmt')],
      [_join(resolvedDartSdk, 'bin', 'dartdoc')],
      [_join(resolvedFlutterSdk, 'bin', 'flutter'), '--no-version-check'],
      [_join(flutterDartSdkDir, 'bin', 'dart'), 'analyze'],
      env,
      useGlobalDartdoc,
    );
    await toolEnv._init();
    return toolEnv;
  }

  Future<String> runAnalyzer(
    String packageDir,
    String dir,
    bool usesFlutter, {
    required InspectOptions inspectOptions,
  }) async {
    final analysisOptionsFile =
        File(p.join(packageDir, 'analysis_options.yaml'));
    String? originalOptions;
    if (await analysisOptionsFile.exists()) {
      originalOptions = await analysisOptionsFile.readAsString();
    }
    final rawOptionsContent = inspectOptions.analysisOptionsYaml ??
        await getDefaultAnalysisOptionsYaml(
          usesFlutter: usesFlutter,
          flutterSdkDir: flutterSdkDir,
        );
    final customOptionsContent = updatePassthroughOptions(
        original: originalOptions, custom: rawOptionsContent);
    try {
      await analysisOptionsFile.writeAsString(customOptionsContent);
      final proc = await runProc(
        [
          ...usesFlutter ? _flutterDartAnalyzerCmd : _dartAnalyzerCmd,
          '--format',
          'machine',
          dir,
        ],
        environment: _environment,
        workingDirectory: packageDir,
        deduplicate: true,
        timeout: const Duration(minutes: 5),
      );
      final output = proc.stderr as String;
      if (output.startsWith('Exceeded timeout of ')) {
        throw ToolException('Running `dart analyze` timed out.');
      }
      if ('\n$output'.contains('\nUnhandled exception:\n')) {
        if (output.contains('No dart files found at: .')) {
          log.warning('`dart analyze` found no files to analyze.');
        } else {
          log.severe('Bad input?: $output');
        }
        var errorMessage =
            '\n$output'.split('\nUnhandled exception:\n')[1].split('\n').first;
        throw ToolException('dart analyze exception: $errorMessage');
      }
      return output;
    } finally {
      if (originalOptions == null) {
        await analysisOptionsFile.delete();
      } else {
        await analysisOptionsFile.writeAsString(originalOptions);
      }
    }
  }

  Future<List<String>> filesNeedingFormat(String packageDir, bool usesFlutter,
      {int? lineLength}) async {
    final dirs = await listFocusDirs(packageDir);
    if (dirs.isEmpty) {
      return const [];
    }
    final files = <String>{};
    for (final dir in dirs) {
      final fullPath = p.join(packageDir, dir);

      final params = <String>[];
      if (usesFlutter) {
        params.add('format');
      }
      params.addAll(['--dry-run', '--set-exit-if-changed']);
      if (lineLength != null && lineLength > 0) {
        params.addAll(<String>['--line-length', lineLength.toString()]);
      }
      params.add(fullPath);

      final result = await runProc(
        [...usesFlutter ? _flutterCmd : _dartfmtCmd, ...params],
        environment: _environment,
        timeout: _dartfmtTimeout,
      );
      if (result.exitCode == 0) {
        continue;
      }

      final lines = LineSplitter.split(result.stdout as String)
          .map((file) => p.join(dir, file))
          .toList();

      // `dartfmt` exits with code = 1, `flutter format` exits with code = 127
      if (result.exitCode == 1 || result.exitCode == 127) {
        assert(lines.isNotEmpty);
        files.addAll(lines);
        continue;
      }

      final output = result.stderr.toString().replaceAll('$packageDir/', '');
      final errorMsg = LineSplitter.split(output).take(10).join('\n');
      final isUserProblem = output.contains(
              'Could not format because the source could not be parsed') ||
          output.contains('The formatter produced unexpected output.');
      if (!isUserProblem) {
        throw Exception(
          'dartfmt on $dir/ failed with exit code ${result.exitCode}\n$output',
        );
      }
      throw ToolException(errorMsg);
    }
    return files.toList()..sort();
  }

  Future<ProcessResult> _execPubUpgrade(
      String packageDir, Map<String, String> environment) {
    return runProc(
      [..._pubCmd, 'upgrade', '--verbose'],
      workingDirectory: packageDir,
      environment: environment,
    );
  }

  Future<ProcessResult> _execFlutterUpgrade(
          String packageDir, Map<String, String> environment) =>
      runProc(
        [
          ..._flutterCmd,
          'packages',
          'pub',
          'upgrade',
          '--verbose',
        ],
        workingDirectory: packageDir,
        environment: environment,
      );

  Future<Map<String, dynamic>> getFlutterVersion() async {
    final result = _handleProcessErrors(
        await runProc([..._flutterCmd, '--version', '--machine']));
    var content = result.stdout as String;
    if (content.startsWith('Waiting for another flutter')) {
      content = content.split('\n').skip(1).join('\n');
    }
    return json.decode(content) as Map<String, dynamic>;
  }

  Future<bool> detectFlutterUse(String packageDir) async {
    try {
      final pubspec = pubspecFromDir(packageDir);
      return pubspec.usesFlutter;
    } catch (e, st) {
      log.info('Unable to read pubspec.yaml', e, st);
    }
    return false;
  }

  Future<ProcessResult> runUpgrade(String packageDir, bool usesFlutter,
      {int retryCount = 3}) async {
    final backup = await _stripAndAugmentPubspecYaml(packageDir);
    try {
      return await _retryProc(() async {
        if (usesFlutter) {
          return await _execFlutterUpgrade(packageDir, _environment);
        } else {
          return await _execPubUpgrade(packageDir, _environment);
        }
      }, shouldRetry: (result) {
        if (result.exitCode == 0) return false;
        var errOutput = result.stderr as String;
        // find cases where retrying is not going to help – and short-circuit
        if (errOutput.contains('Could not get versions for flutter from sdk')) {
          return false;
        }
        if (errOutput.contains('FINE: Exception type: NoVersionException')) {
          return false;
        }
        return true;
      });
    } finally {
      await _restorePubspecYaml(packageDir, backup);
    }
  }

  Future<Map<String, dynamic>> runPubOutdated(String packageDir,
      {List<String> args = const []}) async {
    final getResult = await runProc(
      [..._pubCmd, 'get'],
      environment: _environment,
      workingDirectory: packageDir,
    );
    if (getResult.exitCode != 0) {
      throw ToolException(
          '`dart pub get` failed: \n\n ```\n${getResult.stderr}\n```');
    }
    final result = await runProc(
      [..._pubCmd, 'outdated', ...args],
      environment: _environment,
      workingDirectory: packageDir,
    );
    if (result.exitCode != 0) {
      throw ToolException('`dart pub outdated` failed: ${result.stderr}');
    } else {
      return json.decode(result.stdout as String) as Map<String, dynamic>;
    }
  }

  Map<String, String> _globalDartdocEnv() {
    final env = Map<String, String>.from(_environment);
    if (pubCacheDir != null) {
      env.remove(_pubCacheKey);
    }
    return env;
  }

  Future<DartdocResult> dartdoc(
    String packageDir,
    String outputDir, {
    String? hostedUrl,
    String? canonicalPrefix,
    bool validateLinks = true,
    bool linkToRemote = false,
    Duration? timeout,
    List<String>? excludedLibs,
  }) async {
    ProcessResult pr;
    final args = [
      '--output',
      outputDir,
    ];
    if (excludedLibs != null && excludedLibs.isNotEmpty) {
      args.addAll(['--exclude', excludedLibs.join(',')]);
    }
    if (hostedUrl != null) {
      args.addAll(['--hosted-url', hostedUrl]);
    }
    if (canonicalPrefix != null) {
      args.addAll(['--rel-canonical-prefix', canonicalPrefix]);
    }
    if (!validateLinks) {
      args.add('--no-validate-links');
    }
    if (linkToRemote) {
      args.add('--link-to-remote');
    }
    if (_useGlobalDartdoc) {
      pr = await runProc(
        [..._pubCmd, 'global', 'run', 'dartdoc', ...args],
        workingDirectory: packageDir,
        environment: _globalDartdocEnv(),
        timeout: timeout,
      );
    } else {
      pr = await runProc(
        [..._dartdocCmd, ...args],
        workingDirectory: packageDir,
        environment: _environment,
        timeout: timeout,
      );
    }
    final hasIndexHtml = await File(p.join(outputDir, 'index.html')).exists();
    final hasIndexJson = await File(p.join(outputDir, 'index.json')).exists();
    return DartdocResult(pr, pr.exitCode == 15, hasIndexHtml, hasIndexJson);
  }

  /// Removes the dev_dependencies from the pubspec.yaml
  /// Adds lower-bound minimal SDK constraint - if missing.
  /// Returns the backup file with the original content.
  Future<File> _stripAndAugmentPubspecYaml(String packageDir) async {
    final now = DateTime.now();
    final backup = File(
        p.join(packageDir, 'pana-${now.millisecondsSinceEpoch}-pubspec.yaml'));

    final pubspec = File(p.join(packageDir, 'pubspec.yaml'));
    final original = await pubspec.readAsString();
    final parsed = yamlToJson(original) ?? <String, dynamic>{};
    parsed.remove('dev_dependencies');
    parsed.remove('dependency_overrides');

    // `pub` client checks if pubspec.yaml has no lower-bound SDK constraint,
    // and throws an exception if it is missing. While we no longer accept
    // new packages without such constraint, the old versions are still valid
    // and should be analyzed.
    final environment = parsed.putIfAbsent('environment', () => {});
    if (environment is Map) {
      VersionConstraint? vc;
      if (environment['sdk'] is String) {
        try {
          vc = VersionConstraint.parse(environment['sdk'] as String);
        } catch (_) {}
      }
      final range = vc is VersionRange ? vc : null;
      if (range != null &&
          range.min != null &&
          !range.min!.isAny &&
          !range.min!.isEmpty) {
        // looks good
      } else {
        final maxValue = range?.max == null
            ? '<=${_runtimeInfo!.sdkVersion}'
            : '${range!.includeMax ? '<=' : '<'}${range.max}';
        environment['sdk'] = '>=1.0.0 $maxValue';
      }
    }

    await pubspec.rename(backup.path);
    await pubspec.writeAsString(json.encode(parsed));

    return backup;
  }

  Future _restorePubspecYaml(String packageDir, File backup) async {
    final pubspec = File(p.join(packageDir, 'pubspec.yaml'));
    await backup.rename(pubspec.path);
  }
}

class DartdocResult {
  final ProcessResult processResult;
  final bool wasTimeout;
  final bool hasIndexHtml;
  final bool hasIndexJson;

  DartdocResult(this.processResult, this.wasTimeout, this.hasIndexHtml,
      this.hasIndexJson);

  bool get wasSuccessful =>
      processResult.exitCode == 0 && hasIndexHtml && hasIndexJson;
}

class DartSdkInfo {
  static final _sdkRegexp = RegExp(
    r'Dart \w+ version:\s([^\s]+)(?:\s\((?:[^\)]+)\))?\s\(([^\)]+)\) on "(\w+)"',
  );

  // TODO: parse an actual `DateTime` here. Likely requires using pkg/intl
  final String? dateString;
  final String? platform;
  final Version version;

  DartSdkInfo._(this.version, this.dateString, this.platform);

  factory DartSdkInfo.parse(String versionOutput) {
    var match = _sdkRegexp.firstMatch(versionOutput);
    var version = Version.parse(match![1]!);
    var dateString = match[2];
    var platform = match[3];

    return DartSdkInfo._(version, dateString, platform);
  }
}

const _pubCacheKey = 'PUB_CACHE';
const _pubEnvironmentKey = 'PUB_ENVIRONMENT';

String _join(String? path, String binDir, String executable) {
  var cmd = path == null ? executable : p.join(path, binDir, executable);
  if (Platform.isWindows) {
    final ext = executable == 'dart' ? 'exe' : 'bat';
    cmd = '$cmd.$ext';
  }
  return cmd;
}

class ToolException implements Exception {
  final String message;
  ToolException(this.message);

  @override
  String toString() {
    return 'Exception: $message';
  }
}

ProcessResult _handleProcessErrors(ProcessResult result) {
  if (result.exitCode != 0) {
    if (result.exitCode == 69) {
      // could be a pub error. Let's try to parse!
      var lines = LineSplitter.split(result.stderr as String)
          .where((l) => l.startsWith('ERR '))
          .join('\n');
      if (lines.isNotEmpty) {
        throw Exception(lines);
      }
    }

    throw Exception('Problem running proc: exit code - ' +
        [result.exitCode, result.stdout, result.stderr]
            .map((e) => e.toString().trim())
            .join('<***>'));
  }
  return result;
}

/// Executes [body] and returns with the first clean or the last failure result.
Future<ProcessResult> _retryProc(
  Future<ProcessResult> Function() body, {
  required bool Function(ProcessResult pr) shouldRetry,
  int maxAttempt = 3,
  Duration sleep = const Duration(seconds: 1),
}) async {
  ProcessResult? result;
  for (var i = 1; i <= maxAttempt; i++) {
    try {
      result = await body();
      if (!shouldRetry(result)) {
        break;
      }
    } catch (e, st) {
      if (i < maxAttempt) {
        log.info('Async operation failed (attempt: $i of $maxAttempt).', e, st);
        await Future.delayed(sleep);
        continue;
      }
      rethrow;
    }
  }
  return result!;
}
