// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_util.dart' as cli;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:retry/retry.dart';

import 'analysis_options.dart';
import 'internal_model.dart';
import 'logging.dart';
import 'model.dart' show PanaRuntimeInfo;
import 'package_analyzer.dart' show InspectOptions;
import 'pana_cache.dart';
import 'tool/run_constrained.dart';
import 'utils.dart';
import 'version.dart';

const _dartFormatTimeout = Duration(minutes: 5);
const _defaultMaxFileCount = 10 * 1000 * 1000; // 10 million files
const _defaultMaxTotalLengthBytes = 2 * 1024 * 1024 * 1024; // 2 GiB

class ToolEnvironment {
  final String? dartSdkDir;
  final String? flutterSdkDir;
  final String? pubCacheDir;
  final PanaCache panaCache;
  final _DartSdk _dartSdk;
  final _FlutterSdk _flutterSdk;
  PanaRuntimeInfo? _runtimeInfo;
  final bool _useGlobalDartdoc;
  final String? _globalDartdocVersion;

  bool _globalDartdocActivated = false;

  ToolEnvironment._(
    this.dartSdkDir,
    this.flutterSdkDir,
    this.pubCacheDir,
    this.panaCache,
    this._dartSdk,
    this._flutterSdk,
    this._useGlobalDartdoc,
    this._globalDartdocVersion,
  );

  ToolEnvironment.fake({
    this.dartSdkDir,
    this.flutterSdkDir,
    this.pubCacheDir,
    PanaCache? panaCache,
    Map<String, String> environment = const <String, String>{},
    required PanaRuntimeInfo runtimeInfo,
  })  : panaCache = panaCache ?? PanaCache(),
        _dartSdk = _DartSdk._(null, environment),
        _flutterSdk =
            _FlutterSdk._(null, environment, _DartSdk._(null, environment)),
        _useGlobalDartdoc = false,
        _globalDartdocVersion = null,
        _runtimeInfo = runtimeInfo;

  PanaRuntimeInfo get runtimeInfo => _runtimeInfo!;

  Future _init() async {
    final dartVersionResult = await runConstrained(
      [..._dartSdk.dartCmd, '--version'],
      environment: _dartSdk.environment,
      throwOnError: true,
    );
    final dartSdkInfo = DartSdkInfo.parse(dartVersionResult.asJoinedOutput);
    Map<String, dynamic>? flutterVersions;
    try {
      flutterVersions = await _getFlutterVersion();
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
    String? panaCacheDir,
    Map<String, String>? environment,
    bool useGlobalDartdoc = true,
    String? globalDartdocVersion,
  }) async {
    dartSdkDir ??= cli.getSdkPath();
    final resolvedDartSdk = await _resolve(dartSdkDir);
    final resolvedFlutterSdk = await _resolve(flutterSdkDir);
    final resolvedPubCache = await _resolve(pubCacheDir);
    final resolvedPanaCache = await _resolve(panaCacheDir);
    final env = <String, String>{
      ...?environment,
      if (resolvedPubCache != null) _pubCacheKey: resolvedPubCache,
      'CI': 'true', // suppresses analytics for both Dart and Flutter
    };

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
    final flutterSdk = await _FlutterSdk.detect(flutterSdkDir, env);
    if (flutterSdk._dartSdk._baseDir == null) {
      log.warning(
          'Flutter SDK path was not specified, pana will use the default '
          'Dart SDK to run `dart analyze` on Flutter packages.');
    }

    final toolEnv = ToolEnvironment._(
      resolvedDartSdk,
      resolvedFlutterSdk,
      resolvedPubCache,
      PanaCache(path: resolvedPanaCache),
      await _DartSdk.detect(dartSdkDir, env),
      flutterSdk,
      useGlobalDartdoc,
      globalDartdocVersion,
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
    final command =
        usesFlutter ? _flutterSdk.dartAnalyzeCmd : _dartSdk.dartAnalyzeCmd;

    final analysisOptionsFile =
        File(p.join(packageDir, 'analysis_options.yaml'));
    String? originalOptions;
    if (await analysisOptionsFile.exists()) {
      originalOptions = await analysisOptionsFile.readAsString();
    }
    final rawOptionsContent = await getDefaultAnalysisOptionsYaml(
      usesFlutter: usesFlutter,
      flutterSdkDir: flutterSdkDir,
    );
    final customOptionsContent = updatePassthroughOptions(
        original: originalOptions, custom: rawOptionsContent);
    try {
      await analysisOptionsFile.writeAsString(customOptionsContent);
      final proc = await runConstrained(
        [...command, '--format', 'machine', dir],
        environment:
            usesFlutter ? _flutterSdk.environment : _dartSdk.environment,
        workingDirectory: packageDir,
        timeout: const Duration(minutes: 5),
      );
      if (proc.wasOutputExceeded) {
        throw ToolException(
            'Running `dart analyze` produced too large output.', proc);
      }
      final output = proc.asJoinedOutput;
      if (proc.wasTimeout) {
        throw ToolException('Running `dart analyze` timed out.', proc);
      }
      if ('\n$output'.contains('\nUnhandled exception:\n')) {
        if (output.contains('No dart files found at: .')) {
          log.warning('`dart analyze` found no files to analyze.');
        } else {
          log.severe('Bad input?: $output');
        }
        var errorMessage =
            '\n$output'.split('\nUnhandled exception:\n')[1].split('\n').first;
        throw ToolException('dart analyze exception: $errorMessage', proc);
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

      final params = <String>[
        'format',
        '--output=none',
        '--set-exit-if-changed',
      ];
      if (lineLength != null && lineLength > 0) {
        params.addAll(<String>['--line-length', lineLength.toString()]);
      }
      params.add(fullPath);

      final result = await runConstrained(
        [..._dartSdk.dartCmd, ...params],
        environment:
            usesFlutter ? _flutterSdk.environment : _dartSdk.environment,
        timeout: _dartFormatTimeout,
      );
      if (result.exitCode == 0) {
        continue;
      }

      final dirPrefix = packageDir.endsWith('/') ? packageDir : '$packageDir/';
      final output = result.asJoinedOutput;
      final lines = LineSplitter.split(result.asJoinedOutput)
          .where((l) => l.startsWith('Changed'))
          .map((l) => l.substring(8).replaceAll(dirPrefix, '').trim())
          .toList();

      // `dart format` exits with code = 1
      if (result.exitCode == 1) {
        assert(lines.isNotEmpty);
        files.addAll(lines);
        continue;
      }

      final errorMsg = LineSplitter.split(output).take(10).join('\n');
      final isUserProblem = output.contains(
              'Could not format because the source could not be parsed') ||
          output.contains('The formatter produced unexpected output.');
      if (!isUserProblem) {
        throw Exception(
          'dart format on $dir/ failed with exit code ${result.exitCode}\n$output',
        );
      }
      throw ToolException(errorMsg, result);
    }
    return files.toList()..sort();
  }

  Future<Map<String, dynamic>> _getFlutterVersion() async {
    final result = await runConstrained(
      [..._flutterSdk.flutterCmd, '--version', '--machine'],
      throwOnError: true,
    );
    final waitingForString = 'Waiting for another flutter';
    return result.parseJson(transform: (content) {
      if (content.contains(waitingForString)) {
        return content
            .split('\n')
            .where((e) => !e.contains(waitingForString))
            .join('\n');
      } else {
        return content;
      }
    });
  }

  Future<PanaProcessResult> runUpgrade(
    String packageDir,
    bool usesFlutter, {
    int retryCount = 3,
  }) async {
    return await _withStripAndAugmentPubspecYaml(packageDir, () async {
      final retryOptions = const RetryOptions(maxAttempts: 3);
      bool retryIf(PanaProcessResult result) {
        final errOutput = result.stderr.asString;
        // find cases where retrying is not going to help – and short-circuit
        if (errOutput.contains('Could not get versions for flutter from sdk')) {
          return false;
        }
        if (errOutput.contains('FINE: Exception type: NoVersionException')) {
          return false;
        }
        return true;
      }

      if (usesFlutter) {
        return await runConstrained(
          [
            ..._flutterSdk.flutterCmd,
            'packages',
            'pub',
            'upgrade',
            '--no-example',
            '--verbose',
          ],
          workingDirectory: packageDir,
          environment:
              usesFlutter ? _flutterSdk.environment : _dartSdk.environment,
          retryIf: retryIf,
          retryOptions: retryOptions,
        );
      } else {
        return await runConstrained(
          [
            ..._dartSdk.dartCmd,
            'pub',
            'upgrade',
            '--no-example',
            '--verbose',
          ],
          workingDirectory: packageDir,
          environment:
              usesFlutter ? _flutterSdk.environment : _dartSdk.environment,
          retryIf: retryIf,
          retryOptions: retryOptions,
        );
      }
    });
  }

  Future<Outdated> runPubOutdated(
    String packageDir, {
    List<String> args = const [],
    required bool usesFlutter,
  }) async {
    final pubCmd = usesFlutter
        ?
        // Use `flutter pub pub` to get the 'raw' pub command. This avoids
        // issues with `flutter pub get` running in the example directory,
        // argument parsing differing and other misalignments between `dart pub`
        // and `flutter pub` (see https://github.com/dart-lang/pub/issues/2971).
        [..._flutterSdk.flutterCmd, 'pub', 'pub']
        : [..._dartSdk.dartCmd, 'pub'];
    final cmdLabel = usesFlutter ? 'flutter' : 'dart';
    return await _withStripAndAugmentPubspecYaml(packageDir, () async {
      Future<PanaProcessResult> runPubGet() async {
        final pr = await runConstrained(
          [...pubCmd, 'get', '--no-example'],
          environment:
              usesFlutter ? _flutterSdk.environment : _dartSdk.environment,
          workingDirectory: packageDir,
        );
        return pr;
      }

      final firstPubGet = await runPubGet();
      // Flutter on CI may download additional assets, which will change
      // the output and won't match the expected on in the golden files.
      // Running a second `pub get` will make sure that the output is consistent.
      final secondPubGet = usesFlutter ? await runPubGet() : firstPubGet;
      if (secondPubGet.wasError) {
        // Stripping extra verbose log lines which make Flutter differ on different environment.
        final stderr = ProcessOutput.from(
          secondPubGet.stderr.asString
              .split('---- Log transcript ----\n')
              .first
              .split('pub get failed (1;')
              .first,
        );
        final pr = secondPubGet.change(stderr: stderr);
        throw ToolException(
          '`$cmdLabel pub get` failed:\n\n```\n${pr.asTrimmedOutput}\n```',
          pr,
        );
      }

      final result = await runConstrained(
        [
          ...pubCmd,
          'outdated',
          ...args,
        ],
        environment:
            usesFlutter ? _flutterSdk.environment : _dartSdk.environment,
        workingDirectory: packageDir,
      );
      if (result.wasError) {
        throw ToolException(
          '`$cmdLabel pub outdated` failed:\n\n```\n${result.asTrimmedOutput}\n```',
          result,
        );
      } else {
        return Outdated.fromJson(result.parseJson());
      }
    });
  }

  Future<PanaProcessResult> dartdoc(
    String packageDir,
    String outputDir, {
    Duration? timeout,
    required bool usesFlutter,
  }) async {
    final sdkDir =
        usesFlutter ? _flutterSdk._dartSdk._baseDir : _dartSdk._baseDir;

    final args = [
      '--output',
      outputDir,
      '--sanitize-html',
      '--max-file-count',
      '$_defaultMaxFileCount',
      '--max-total-size',
      '$_defaultMaxTotalLengthBytes',
      '--no-validate-links',
      if (sdkDir != null) ...['--sdk-dir', sdkDir],
    ];

    PanaProcessResult pr;

    if (_useGlobalDartdoc) {
      if (!_globalDartdocActivated) {
        await runConstrained(
          [
            ..._dartSdk.dartCmd,
            'pub',
            'global',
            'activate',
            'dartdoc',
            if (_globalDartdocVersion != null) _globalDartdocVersion!,
          ],
          environment: {
            ..._dartSdk.environment,
            'PUB_HOSTED_URL': 'https://pub.dev',
          },
          throwOnError: true,
        );
        _globalDartdocActivated = true;
      }
      pr = await runConstrained(
        [..._dartSdk.dartCmd, 'pub', 'global', 'run', 'dartdoc', ...args],
        workingDirectory: packageDir,
        environment: _dartSdk.environment,
        timeout: timeout,
      );
    } else {
      pr = await runConstrained(
        [..._dartSdk.dartCmd, 'doc', ...args],
        workingDirectory: packageDir,
        environment: _dartSdk.environment,
        timeout: timeout,
      );
    }
    return pr;
  }

  /// Removes the `dev_dependencies` from the `pubspec.yaml`,
  /// and also removes `pubspec_overrides.yaml`.
  ///
  /// Adds lower-bound minimal SDK constraint - if missing.
  ///
  /// Returns the result of the inner function, and restores the
  /// original content upon return.
  Future<R> _withStripAndAugmentPubspecYaml<R>(
    String packageDir,
    FutureOr<R> Function() fn,
  ) async {
    final now = DateTime.now();
    final pubspecBackup = await _stripAndAugmentPubspecYaml(packageDir);

    // backup of pubspec_overrides.yaml
    final poyamlFile = File(p.join(packageDir, 'pubspec_overrides.yaml'));
    File? poyamlBackup;
    if (await poyamlFile.exists()) {
      final path = p.join(
        packageDir,
        'pana-${now.millisecondsSinceEpoch}-pubspec_overrides.yaml',
      );
      poyamlBackup = await poyamlFile.rename(path);
    }

    try {
      return await fn();
    } finally {
      await poyamlBackup?.rename(poyamlFile.path);
      await pubspecBackup.rename(p.join(packageDir, 'pubspec.yaml'));
    }
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
    final match = _sdkRegexp.firstMatch(versionOutput);
    if (match == null) {
      throw FormatException('Couldn\'t parse Dart SDK version: $versionOutput');
    }
    final version = Version.parse(match[1]!);
    final dateString = match[2];
    final platform = match[3];

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

Future<String?> _resolve(String? dir) async {
  if (dir == null) return null;
  return Directory(dir).resolveSymbolicLinks();
}

class _DartSdk {
  final String? _baseDir;
  final Map<String, String> environment;

  _DartSdk._(this._baseDir, this.environment);

  static Future<_DartSdk> detect(
      String? path, Map<String, String> environment) async {
    final resolved = await _resolve(path);
    return _DartSdk._(resolved, environment);
  }

  late final dartCmd = [
    _join(_baseDir, 'bin', 'dart'),
  ];

  late final dartAnalyzeCmd = [...dartCmd, 'analyze'];
}

class _FlutterSdk {
  final String? _baseDir;
  final _DartSdk _dartSdk;
  final Map<String, String> environment;

  _FlutterSdk._(this._baseDir, Map<String, String> environment, this._dartSdk)
      : environment = {
          ...environment,
          if (_baseDir != null) 'FLUTTER_ROOT': _baseDir,
        };

  static Future<_FlutterSdk> detect(
      String? path, Map<String, String> environment) async {
    final resolved = await _resolve(path);

    final dartSdkDir = resolved == null
        ? resolved
        : p.join(resolved, 'bin', 'cache', 'dart-sdk');

    return _FlutterSdk._(
        resolved, environment, await _DartSdk.detect(dartSdkDir, environment));
  }

  late final flutterCmd = [
    _join(_baseDir, 'bin', 'flutter'),
    '--no-version-check',
  ];

  // TODO: remove this after flutter analyze gets machine-readable output.
  // https://github.com/flutter/flutter/issues/23664
  late final dartAnalyzeCmd = _dartSdk.dartAnalyzeCmd;
}
