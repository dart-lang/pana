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
import 'internal_model.dart';
import 'logging.dart';
import 'model.dart' show PanaRuntimeInfo;
import 'package_analyzer.dart' show InspectOptions;
import 'tool/flutter_tool.dart';
import 'tool/run_constrained.dart';
import 'utils.dart';
import 'version.dart';

const _dartFormatTimeout = Duration(minutes: 5);
const _defaultMaxFileCount = 10 * 1000 * 1000; // 10 million files
const _defaultMaxTotalLengthBytes = 2 * 1024 * 1024 * 1024; // 2 GiB

/// Configuration class for the SDKs.
class SdkConfig {
  /// The root directory of the SDK (in which there should be a `bin/` directory).
  final String? rootPath;

  /// The path (usually in `$HOME/.config` on Linux) where applications may
  /// store their local configuration data. This can be separately configured
  /// for each SDK, to prevent conflicting overrides of their own settings.
  final String? configHomePath;

  /// The SDK-specific environment.
  final Map<String, String> environment;

  SdkConfig({
    this.rootPath,
    this.configHomePath,
    this.environment = const <String, String>{},
  });

  SdkConfig _changeRootPath(String? rootPath) {
    return SdkConfig(
      rootPath: rootPath,
      configHomePath: configHomePath,
      environment: environment,
    );
  }

  /// Resolves symbolic links in the specified paths and extends [environment].
  Future<SdkConfig> _resolveAndExtend({
    required Map<String, String> environment,
    bool isFlutterSdk = false,
  }) async {
    final resolvedRootPath = await _resolve(rootPath);
    final resolvedConfigHomePath = await _resolve(configHomePath);
    return SdkConfig(
      rootPath: resolvedRootPath,
      configHomePath: resolvedConfigHomePath,
      environment: {
        ...this.environment,
        ...environment,
        if (resolvedConfigHomePath != null)
          'XDG_CONFIG_HOME': resolvedConfigHomePath,
        if (resolvedRootPath != null && isFlutterSdk)
          'FLUTTER_ROOT': resolvedRootPath,
      },
    );
  }
}

class ToolEnvironment {
  final String? pubCacheDir;
  final _DartSdk _dartSdk;
  final _FlutterSdk _flutterSdk;
  PanaRuntimeInfo? _runtimeInfo;
  final String? _dartdocVersion;
  final bool _useAnalysisIncludes;

  bool _globalDartdocActivated = false;

  ToolEnvironment._(
    this.pubCacheDir,
    this._dartSdk,
    this._flutterSdk,
    this._dartdocVersion,
    this._useAnalysisIncludes,
  );

  ToolEnvironment.fake({
    this.pubCacheDir,
    Map<String, String> environment = const <String, String>{},
    required PanaRuntimeInfo runtimeInfo,
  }) : _dartSdk = _DartSdk._(SdkConfig(environment: environment)),
       _flutterSdk = _FlutterSdk._(
         SdkConfig(environment: environment),
         _DartSdk._(SdkConfig(environment: environment)),
       ),
       _dartdocVersion = null,
       _runtimeInfo = runtimeInfo,
       _useAnalysisIncludes = false;

  PanaRuntimeInfo get runtimeInfo => _runtimeInfo!;

  Future<void> _init() async {
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
    SdkConfig? dartSdkConfig,
    SdkConfig? flutterSdkConfig,
    String? pubCacheDir,
    String? pubHostedUrl,

    /// When specified, this version of `dartdoc` will be initialized
    /// through `dart pub global activate` and used with `dart pub global run`,
    /// otherwise the SDK's will be used.
    ///
    /// Note: To use the latest `dartdoc`, use the version value `any`.
    String? dartdocVersion,

    /// When true, the analysis_options.yaml's `include` references will be used.
    bool? useAnalysisIncludes,
  }) async {
    dartSdkConfig ??= SdkConfig(rootPath: cli.sdkPath);
    flutterSdkConfig ??= SdkConfig();
    final resolvedPubCache = await _resolve(pubCacheDir);

    final origPubEnvValue = Platform.environment[_pubEnvironmentKey] ?? '';
    final origPubEnvValues = origPubEnvValue
        .split(':')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    final env = <String, String>{
      'CI': 'true', // suppresses analytics for both Dart and Flutter
      if (resolvedPubCache != null) _pubCacheKey: resolvedPubCache,
      if (pubHostedUrl != null) 'PUB_HOSTED_URL': pubHostedUrl,
      _pubEnvironmentKey: [...origPubEnvValues, 'bot.pkg_pana'].join(':'),
    };

    // Flutter stores its internal SDK in its bin/cache/dart-sdk directory.
    // We can use that directory only if Flutter SDK path was specified,
    // TODO: remove this after flutter analyze gets machine-readable output.
    // https://github.com/flutter/flutter/issues/23664
    final flutterSdk = await _FlutterSdk.detect(flutterSdkConfig, env);
    if (flutterSdk._dartSdk._config.rootPath == null) {
      log.warning(
        'Flutter SDK path was not specified, pana will use the default '
        'Dart SDK to run `dart analyze` on Flutter packages.',
      );
    }

    final toolEnv = ToolEnvironment._(
      resolvedPubCache,
      await _DartSdk.detect(dartSdkConfig, env),
      flutterSdk,
      dartdocVersion,
      useAnalysisIncludes ??
          Platform.environment['PANA_ANALYSIS_INCLUDES'] == '1',
    );
    await toolEnv._init();
    return toolEnv;
  }

  /// Downloads and unpacks a package archive into the [outputDir] path
  /// using the `dart pub unpack` command.
  Future<void> unpack({
    required String package,
    String? version,
    String? pubHostedUrl,
    required String outputDir,
  }) async {
    final param = [package, if (version != null) version].join(':');
    final targetDir = Directory(outputDir);
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await withTempDir((downloadDir) async {
      await _runPub(
        ['unpack', param, '--output', downloadDir, '--no-resolve'],
        usesFlutter: false,
        environment: {if (pubHostedUrl != null) 'PUB_HOSTED_URL': pubHostedUrl},
        throwOnError: true,
      );
      final subdir = Directory(
        downloadDir,
      ).listSync().whereType<Directory>().single;
      await subdir.rename(targetDir.path);
    });
  }

  Future<T> _withRestrictedAnalysisOptions<T>(
    String packageDir,
    Future<T> Function() fn,
  ) async {
    final analysisOptionsFile = File(
      p.join(packageDir, 'analysis_options.yaml'),
    );
    String? originalOptions;
    if (await analysisOptionsFile.exists()) {
      originalOptions = await analysisOptionsFile.readAsString();
    }
    final rawOptionsContent = await getDefaultAnalysisOptionsYaml();
    final customOptionsContent = updatePassthroughOptions(
      original: originalOptions,
      custom: rawOptionsContent,
      useAnalysisIncludes: _useAnalysisIncludes,
    );
    try {
      await analysisOptionsFile.writeAsString(customOptionsContent);
      return await fn();
    } finally {
      if (originalOptions == null) {
        await analysisOptionsFile.delete();
      } else {
        await analysisOptionsFile.writeAsString(originalOptions);
      }
    }
  }

  Future<String> runAnalyzer(
    String packageDir,
    String dir,
    bool usesFlutter, {
    required InspectOptions inspectOptions,
  }) async {
    final command = usesFlutter
        ? _flutterSdk.dartAnalyzeCmd
        : _dartSdk.dartAnalyzeCmd;

    return await _withRestrictedAnalysisOptions(packageDir, () async {
      final proc = await runConstrained(
        [...command, '--format', 'machine', dir],
        environment: usesFlutter
            ? _flutterSdk.environment
            : _dartSdk.environment,
        workingDirectory: packageDir,
        timeout: const Duration(minutes: 5),
      );
      if (proc.wasOutputExceeded) {
        throw ToolException(
          'Running `dart analyze` produced too large output.',
          proc,
        );
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
        var errorMessage = '\n$output'
            .split('\nUnhandled exception:\n')[1]
            .split('\n')
            .first;
        throw ToolException('dart analyze exception: $errorMessage', proc);
      }
      return output;
    });
  }

  Future<List<String>> filesNeedingFormat(
    String packageDir,
    bool usesFlutter,
  ) async {
    return _withRestrictedAnalysisOptions(packageDir, () async {
      await runPub(packageDir, usesFlutter: usesFlutter, command: 'get');

      final files = <String>{};

      final params = <String>[
        'format',
        '--output=none',
        '--set-exit-if-changed',
      ];
      params.add(packageDir);

      final result = await runConstrained(
        [..._dartSdk.dartCmd, ...params],
        environment: usesFlutter
            ? _flutterSdk.environment
            : _dartSdk.environment,
        timeout: _dartFormatTimeout,
      );
      if (result.exitCode == 0) {
        return [];
      }

      final dirPrefix = packageDir.endsWith('/') ? packageDir : '$packageDir/';
      final output = result.asJoinedOutput;
      final lines = LineSplitter.split(result.asJoinedOutput)
          .where((l) => l.startsWith('Changed'))
          .map((l) => l.substring(8).replaceAll(dirPrefix, '').trim())
          .where(isAnalysisTarget)
          .toList();

      // `dart format` exits with code = 1
      if (result.exitCode == 1) {
        assert(lines.isNotEmpty);
        files.addAll(lines);
        return files.toList()..sort();
      }

      final errorMsg = LineSplitter.split(output).take(10).join('\n');
      final isUserProblem =
          output.contains(
            'Could not format because the source could not be parsed',
          ) ||
          output.contains('The formatter produced unexpected output.');
      if (!isUserProblem) {
        throw Exception(
          '`dart format` failed with exit code ${result.exitCode}\n$output',
        );
      }
      throw ToolException(errorMsg, result);
    });
  }

  Future<Map<String, dynamic>> _getFlutterVersion() async {
    final result = await runConstrained(
      [..._flutterSdk.flutterCmd, '--version', '--machine'],
      environment: _flutterSdk.environment,
      throwOnError: true,
    );
    return result.parseJson(transform: stripIntermittentFlutterMessages);
  }

  Future<PanaProcessResult> runPub(
    String packageDir, {
    required bool usesFlutter,
    required String command,
  }) async {
    return await _withStripAndAugmentPubspecYaml(packageDir, () async {
      return await _runPub(
        [command, '--no-example'],
        usesFlutter: usesFlutter,
        workingDirectory: packageDir,
      );
    });
  }

  Future<PanaProcessResult> _runPub(
    List<String> commands, {
    required bool usesFlutter,
    String? workingDirectory,
    bool? throwOnError,
    Map<String, String>? environment,
  }) async {
    return await runConstrained(
      [
        if (usesFlutter) ...[
          ..._flutterSdk.flutterCmd,
          'packages',
        ] else
          ..._dartSdk.dartCmd,
        'pub',
        ...commands,
      ],
      workingDirectory: workingDirectory,
      environment: {
        ...(usesFlutter ? _flutterSdk.environment : _dartSdk.environment),
        ...?environment,
      },
      throwOnError: throwOnError ?? false,
    );
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
          environment: usesFlutter
              ? _flutterSdk.environment
              : _dartSdk.environment,
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
        [...pubCmd, 'outdated', ...args],
        environment: usesFlutter
            ? _flutterSdk.environment
            : _dartSdk.environment,
        workingDirectory: packageDir,
      );
      if (result.wasError) {
        throw ToolException(
          '`$cmdLabel pub outdated` failed:\n\n```\n${result.asTrimmedOutput}\n```',
          result,
        );
      } else {
        final outdated = Outdated.fromJson(result.parseJson());
        final lockFile = File(p.join(packageDir, 'pubspec.lock'));
        final lockContent =
            yamlToJson(await lockFile.readAsString()) ?? const {};
        final lockPackages = lockContent['packages'];
        if (lockPackages is! Map<String, dynamic>) {
          throw ToolException(
            '`$cmdLabel pub outdated` failed to generate a valid `pubspec.lock`.',
          );
        }
        final sdkPackages = lockPackages.entries
            .where((e) {
              final data = e.value;
              if (data is! Map<String, dynamic>) {
                return false;
              }
              return data['source'] == 'sdk';
            })
            .map((e) => e.key)
            .toSet();

        return Outdated(
          outdated.packages
              // Filter SDK packages.
              .where((p) => !sdkPackages.contains(p.package))
              .toList(),
        );
      }
    });
  }

  Future<PanaProcessResult> dartdoc(
    String packageDir,
    String outputDir, {
    Duration? timeout,
    required bool usesFlutter,
  }) async {
    final sdkDir = usesFlutter
        ? _flutterSdk._dartSdk._config.rootPath
        : _dartSdk._config.rootPath;

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

    if (_dartdocVersion == 'sdk') {
      final command = usesFlutter
          ? _flutterSdk._dartSdk.dartCmd
          : _dartSdk.dartCmd;
      return await runConstrained(
        [...command, 'doc', ...args],
        workingDirectory: packageDir,
        environment: _dartSdk.environment,
        timeout: timeout,
      );
    } else {
      final command = usesFlutter ? _flutterSdk.flutterCmd : _dartSdk.dartCmd;
      if (!_globalDartdocActivated) {
        await runConstrained(
          [
            ...command,
            'pub',
            'global',
            'activate',
            'dartdoc',
            if (_dartdocVersion != null) _dartdocVersion,
          ],
          environment: {
            ..._dartSdk.environment,
            'PUB_HOSTED_URL': 'https://pub.dev',
          },
          throwOnError: true,
        );
        _globalDartdocActivated = true;
      }
      return await runConstrained(
        [...command, 'pub', 'global', 'run', 'dartdoc', ...args],
        workingDirectory: packageDir,
        environment: usesFlutter
            ? _flutterSdk.environment
            : _dartSdk.environment,
        timeout: timeout,
      );
    }
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

    // Create a backup of the pubspec_overrides.yaml file.
    final pubspecOverridesFile = File(
      p.join(packageDir, 'pubspec_overrides.yaml'),
    );
    File? pubspecOverridesBackup;
    if (await pubspecOverridesFile.exists()) {
      final path = p.join(
        packageDir,
        'pana-${now.millisecondsSinceEpoch}-pubspec_overrides.yaml',
      );
      pubspecOverridesBackup = await pubspecOverridesFile.rename(path);
    }

    try {
      return await fn();
    } finally {
      await pubspecOverridesBackup?.rename(pubspecOverridesFile.path);
      await pubspecBackup.rename(p.join(packageDir, 'pubspec.yaml'));
    }
  }

  /// Removes aspects of `pubspec.yaml` that are irrelevant when consuming the
  /// package.
  ///
  /// * Removes `dev_dependencies` and `dependency_overrides` These have no
  ///   effect on the consuming resolution.
  /// * Removes `workspace` and `resolution` These have no effect on the
  ///   consuming resolution, and might prevent the package from resolving on
  ///   its own.
  ///
  /// Returns the backup file with the original content.
  Future<File> _stripAndAugmentPubspecYaml(String packageDir) async {
    final now = DateTime.now();
    final backup = File(
      p.join(packageDir, 'pana-${now.millisecondsSinceEpoch}-pubspec.yaml'),
    );

    // extract the package name from the `include: package:<package>/path.yaml` entry in analysis options:
    final includedPackages = <String>{};
    final analysisOptionsFile = File(
      p.join(packageDir, 'analysis_options.yaml'),
    );
    if (_useAnalysisIncludes && await analysisOptionsFile.exists()) {
      void addPackageInclude(String includeValue) {
        final include = includeValue.trim();
        if (include.startsWith('package:')) {
          includedPackages.add(
            include.substring('package:'.length).split('/').first,
          );
        }
      }

      final analysisOptions = await analysisOptionsFile.readAsString();
      final parsed = yamlToJson(analysisOptions);
      final includeValue = parsed?['include'];
      if (includeValue is String) {
        addPackageInclude(includeValue);
      } else if (includeValue is List) {
        for (final v in includeValue.whereType<String>()) {
          addPackageInclude(v);
        }
      }
    }

    final pubspec = File(p.join(packageDir, 'pubspec.yaml'));
    final original = await pubspec.readAsString();
    final parsed = yamlToJson(original) ?? <String, dynamic>{};
    final oldDevDependencies = parsed.remove('dev_dependencies');
    if (oldDevDependencies is Map<String, dynamic>) {
      final keptDevDependencies = <String, dynamic>{};
      for (final name in oldDevDependencies.keys) {
        if (!includedPackages.contains(name)) {
          continue;
        }
        final value = oldDevDependencies[name];
        if (value is Map &&
            (value.containsKey('path') || value.containsKey('git'))) {
          continue;
        }
        keptDevDependencies[name] = value;
      }
      if (keptDevDependencies.isNotEmpty) {
        parsed['dev_dependencies'] = keptDevDependencies;
      }
    }
    parsed.remove('dependency_overrides');
    parsed.remove('workspace');
    parsed.remove('resolution');

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
  final SdkConfig _config;
  Map<String, String> get environment => _config.environment;

  _DartSdk._(this._config);

  static Future<_DartSdk> detect(
    SdkConfig config,
    Map<String, String> environment,
  ) async {
    final resolved = await config._resolveAndExtend(environment: environment);
    return _DartSdk._(resolved);
  }

  late final dartCmd = [_join(_config.rootPath, 'bin', 'dart')];

  late final dartAnalyzeCmd = [...dartCmd, 'analyze'];
}

class _FlutterSdk {
  final SdkConfig _config;
  final _DartSdk _dartSdk;
  Map<String, String> get environment => _config.environment;

  _FlutterSdk._(this._config, this._dartSdk);

  static Future<_FlutterSdk> detect(
    SdkConfig config,
    Map<String, String> environment,
  ) async {
    final resolved = await config._resolveAndExtend(
      environment: environment,
      isFlutterSdk: true,
    );

    final dartSdkRootPath = resolved.rootPath == null
        ? null
        : p.join(resolved.rootPath!, 'bin', 'cache', 'dart-sdk');

    return _FlutterSdk._(
      resolved,
      await _DartSdk.detect(
        config._changeRootPath(dartSdkRootPath),
        resolved.environment,
      ),
    );
  }

  late final flutterCmd = [
    _join(_config.rootPath, 'bin', 'flutter'),
    '--no-version-check',
  ];

  // TODO: remove this after flutter analyze gets machine-readable output.
  // https://github.com/flutter/flutter/issues/23664
  late final dartAnalyzeCmd = _dartSdk.dartAnalyzeCmd;
}
