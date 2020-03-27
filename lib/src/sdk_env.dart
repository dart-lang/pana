// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_util.dart' as cli;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'analysis_options.dart';
import 'logging.dart';
import 'model.dart' show PanaRuntimeInfo;
import 'package_analyzer.dart' show InspectOptions;
import 'pubspec.dart';
import 'utils.dart';
import 'version.dart';

final _logger = Logger('pana.env');

const _dartfmtTimeout = Duration(minutes: 5);

class ToolEnvironment {
  final String dartSdkDir;
  final String pubCacheDir;
  final String _dartCmd;
  final String _pubCmd;
  final String _dartAnalyzerCmd;
  final String _dartfmtCmd;
  final String _dartdocCmd;
  final String _flutterCmd;
  // TODO: remove this after flutter analyze gets machine-readable output.
  // https://github.com/flutter/flutter/issues/23664
  final String _flutterDartAnalyzerCmd;
  final Map<String, String> _environment;
  PanaRuntimeInfo _runtimeInfo;
  bool _useGlobalDartdoc;

  ToolEnvironment._(
    this.dartSdkDir,
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

  PanaRuntimeInfo get runtimeInfo => _runtimeInfo;

  Future _init() async {
    final dartVersionResult = handleProcessErrors(
        await runProc(_dartCmd, ['--version'], environment: _environment));
    final dartVersionString = dartVersionResult.stderr.toString().trim();
    final dartSdkInfo = DartSdkInfo.parse(dartVersionString);
    Map<String, dynamic> flutterVersions;
    try {
      flutterVersions = await getFlutterVersion();
    } catch (e) {
      _logger.warning('Unable to detect Flutter version.', e);
    }
    _runtimeInfo = PanaRuntimeInfo(
      panaVersion: packageVersion,
      sdkVersion: dartSdkInfo.version.toString(),
      flutterVersions: flutterVersions,
    );
  }

  static Future<ToolEnvironment> create({
    String dartSdkDir,
    String flutterSdkDir,
    String pubCacheDir,
    Map<String, String> environment,
    bool useGlobalDartdoc = false,
  }) async {
    Future<String> resolve(String dir) async {
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
      _logger.warning(
          'Flutter SDK path was not specified, pana will use the default '
          'Dart SDK to run `dartanalyzer` on Flutter packages.');
    }

    final toolEnv = ToolEnvironment._(
      resolvedDartSdk,
      resolvedPubCache,
      _join(resolvedDartSdk, 'bin', 'dart'),
      _join(resolvedDartSdk, 'bin', 'pub'),
      _join(resolvedDartSdk, 'bin', 'dartanalyzer'),
      _join(resolvedDartSdk, 'bin', 'dartfmt'),
      _join(resolvedDartSdk, 'bin', 'dartdoc'),
      _join(resolvedFlutterSdk, 'bin', 'flutter'),
      _join(flutterDartSdkDir, 'bin', 'dartanalyzer'),
      env,
      useGlobalDartdoc,
    );
    await toolEnv._init();
    return toolEnv;
  }

  Future<String> runAnalyzer(
    String packageDir,
    List<String> dirs,
    bool usesFlutter, {
    @required InspectOptions inspectOptions,
  }) async {
    final originalOptionsFile =
        File(p.join(packageDir, 'analysis_options.yaml'));
    String originalOptions;
    if (await originalOptionsFile.exists()) {
      originalOptions = await originalOptionsFile.readAsString();
    }
    final pedanticContent =
        await getPedanticContent(inspectOptions: inspectOptions);
    final pedanticFileName =
        'pedantic_analyis_options_${DateTime.now().microsecondsSinceEpoch}.g.yaml';
    final pedanticOptionsFile = File(p.join(packageDir, pedanticFileName));
    await pedanticOptionsFile.writeAsString(pedanticContent);
    final customFileName =
        'pana_analysis_options_${DateTime.now().microsecondsSinceEpoch}.g.yaml';
    final customOptionsFile = File(p.join(packageDir, customFileName));
    await customOptionsFile.writeAsString(customizeAnalysisOptions(
        originalOptions, usesFlutter, pedanticFileName));
    final params = [
      '--options',
      customOptionsFile.path,
      '--format',
      'machine',
      ...dirs,
    ];
    // TODO: run flutter analyze after it gets machine-readable output support:
    // https://github.com/flutter/flutter/issues/23664
    try {
      final proc = await runProc(
        usesFlutter ? _flutterDartAnalyzerCmd : _dartAnalyzerCmd,
        params,
        environment: _environment,
        workingDirectory: packageDir,
        deduplicate: true,
        timeout: const Duration(minutes: 5),
      );
      final output = proc.stderr as String;
      if ('\n$output'.contains('\nUnhandled exception:\n')) {
        log.severe('Bad input?');
        log.severe(output);
        var errorMessage =
            '\n$output'.split('\nUnhandled exception:\n')[1].split('\n').first;
        throw ArgumentError('dartanalyzer exception: $errorMessage');
      }
      return output;
    } finally {
      // TODO: create a withTempFile utility method that deletes these
      await customOptionsFile.delete();
      await pedanticOptionsFile.delete();
    }
  }

  Future<List<String>> filesNeedingFormat(String packageDir, bool usesFlutter,
      {int lineLength}) async {
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
        usesFlutter ? _flutterCmd : _dartfmtCmd,
        params,
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
      throw Exception(
          'dartfmt on $dir/ failed with exit code ${result.exitCode}\n$output');
    }
    return files.toList()..sort();
  }

  Future<ProcessResult> _execPubUpgrade(
      String packageDir, Map<String, String> environment) {
    return runProc(
      _pubCmd,
      ['upgrade', '--verbosity', 'io', '--no-precompile'],
      workingDirectory: packageDir,
      environment: environment,
    );
  }

  Future<ProcessResult> _execFlutterUpgrade(
          String packageDir, Map<String, String> environment) =>
      runProc(
        _flutterCmd,
        ['packages', 'pub', 'upgrade', '--verbosity', 'io', '--no-precompile'],
        workingDirectory: packageDir,
        environment: environment,
      );

  Future<Map<String, Object>> getFlutterVersion() async {
    var result = handleProcessErrors(
        await runProc(_flutterCmd, ['--version', '--machine']));
    return json.decode(result.stdout as String) as Map<String, Object>;
  }

  Future<bool> detectFlutterUse(String packageDir) async {
    try {
      final pubspec = Pubspec.parseFromDir(packageDir);
      return pubspec.usesFlutter;
    } catch (e, st) {
      _logger.info('Unable to read pubspec.yaml', e, st);
    }
    return false;
  }

  Future<ProcessResult> runUpgrade(String packageDir, bool usesFlutter,
      {int retryCount = 3}) async {
    final backup = await _stripPubspecYaml(packageDir);
    try {
      return await retryProc(() async {
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

  Map<String, String> _globalDartdocEnv() {
    final env = Map<String, String>.from(_environment);
    if (pubCacheDir != null) {
      env.remove(_pubCacheKey);
    }
    return env;
  }

  Future activateGlobalDartdoc(String version) async {
    handleProcessErrors(await runProc(
      _pubCmd,
      ['global', 'activate', 'dartdoc', version],
      environment: _globalDartdocEnv(),
    ));
    _useGlobalDartdoc = true;
  }

  Future<DartdocResult> dartdoc(
    String packageDir,
    String outputDir, {
    String hostedUrl,
    String canonicalPrefix,
    bool validateLinks = true,
    bool linkToRemote = false,
    Duration timeout,
    List<String> excludedLibs,
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
        _pubCmd,
        ['global', 'run', 'dartdoc', ...args],
        workingDirectory: packageDir,
        environment: _globalDartdocEnv(),
        timeout: timeout,
      );
    } else {
      pr = await runProc(
        _dartdocCmd,
        args,
        workingDirectory: packageDir,
        environment: _environment,
        timeout: timeout,
      );
    }
    final hasIndexHtml = await File(p.join(outputDir, 'index.html')).exists();
    final hasIndexJson = await File(p.join(outputDir, 'index.json')).exists();
    return DartdocResult(pr, pr.exitCode == 15, hasIndexHtml, hasIndexJson);
  }

  Future<PackageLocation> getLocation(String package, {String version}) async {
    var args = ['cache', 'add', '--verbose'];
    if (version != null) {
      args.addAll(['--version', version]);
    }
    args.add(package);

    var result = handleProcessErrors(
      await retryProc(
        () => runProc(
          _pubCmd,
          args,
          environment: _environment,
        ),
      ),
    );

    var match = _versionDownloadRegexp
        .allMatches((result.stdout as String).trim())
        .single;
    var pkgMatch = match[1];
    assert(pkgMatch == package);

    var versionString = match[2];
    assert(versionString.endsWith('.'));
    while (versionString.endsWith('.')) {
      versionString = versionString.substring(0, versionString.length - 1);
    }

    if (version != null) {
      assert(versionString == version);
    }

    // now get all installed packages
    result = handleProcessErrors(
      await retryProc(
        () => runProc(_pubCmd, ['cache', 'list'], environment: _environment),
        sleep: const Duration(seconds: 5),
      ),
    );

    var map = json.decode(result.stdout as String) as Map;

    var location =
        map['packages'][package][versionString]['location'] as String;

    if (location == null) {
      throw Exception('Huh? This should be cached!');
    }

    return PackageLocation(package, versionString, location);
  }

  ProcessResult listPackageDirsSync(String packageDir, bool usesFlutter) {
    if (usesFlutter) {
      // flutter env
      return runProcSync(
        _flutterCmd,
        ['packages', 'pub', 'list-package-dirs'],
        workingDirectory: packageDir,
        environment: _environment,
      );
    } else {
      // normal pub
      return runProcSync(
        _pubCmd,
        ['list-package-dirs'],
        workingDirectory: packageDir,
        environment: _environment,
      );
    }
  }

  /// Removes the dev_dependencies from the pubspec.yaml
  /// Returns the backup file with the original content.
  Future<File> _stripPubspecYaml(String packageDir) async {
    final now = DateTime.now();
    final backup = File(
        p.join(packageDir, 'pana-${now.millisecondsSinceEpoch}-pubspec.yaml'));

    final pubspec = File(p.join(packageDir, 'pubspec.yaml'));
    final original = await pubspec.readAsString();
    final parsed = yamlToJson(original);
    parsed.remove('dev_dependencies');
    parsed.remove('dependency_overrides');

    await pubspec.rename(backup.path);
    await pubspec.writeAsString(json.encode(parsed));

    return backup;
  }

  Future _restorePubspecYaml(String packageDir, File backup) async {
    final pubspec = File(p.join(packageDir, 'pubspec.yaml'));
    await backup.rename(pubspec.path);
  }
}

class PackageLocation {
  final String package;
  final String version;
  final String location;

  PackageLocation(this.package, this.version, this.location);
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
    r'Dart VM version:\s([^\s]+)(?:\s\((?:[^\)]+)\))?\s\(([^\)]+)\) on "(\w+)"',
  );

  // TODO: parse an actual `DateTime` here. Likely requires using pkg/intl
  final String dateString;
  final String platform;
  final Version version;

  DartSdkInfo._(this.version, this.dateString, this.platform);

  factory DartSdkInfo.parse(String versionOutput) {
    var match = _sdkRegexp.firstMatch(versionOutput);
    var version = Version.parse(match[1]);
    var dateString = match[2];
    var platform = match[3];

    return DartSdkInfo._(version, dateString, platform);
  }
}

final _versionDownloadRegexp =
    RegExp(r'^MSG : (?:Downloading |Already cached )([\w-]+) (.+)$');

const _pubCacheKey = 'PUB_CACHE';
const _pubEnvironmentKey = 'PUB_ENVIRONMENT';

String _join(String path, String binDir, String executable) {
  var cmd = path == null ? executable : p.join(path, binDir, executable);
  if (Platform.isWindows) {
    final ext = executable == 'dart' ? 'exe' : 'bat';
    cmd = '$cmd.$ext';
  }
  return cmd;
}
