// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_util.dart' as cli;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'analysis_options.dart';
import 'logging.dart';
import 'model.dart' show PanaRuntimeInfo;
import 'pubspec.dart';
import 'utils.dart';
import 'version.dart';

final _logger = new Logger('pana.env');

class ToolEnvironment {
  final String dartSdkDir;
  final String pubCacheDir;
  final String _dartCmd;
  final String _pubCmd;
  final String _dartAnalyzerCmd;
  final String _dartfmtCmd;
  final String _dartdocCmd;
  final String _flutterCmd;
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
    this._environment,
    this._useGlobalDartdoc,
  );

  PanaRuntimeInfo get runtimeInfo => _runtimeInfo;

  Future _init() async {
    final dartVersionResult = handleProcessErrors(
        await runProc(_dartCmd, ['--version'], environment: _environment));
    final dartVersionString = dartVersionResult.stderr.toString().trim();
    final dartSdkInfo = new DartSdkInfo.parse(dartVersionString);
    Map<String, dynamic> flutterVersions;
    try {
      flutterVersions = await getFlutterVersion();
    } catch (_) {
      _logger.warning('Unable to detect Flutter version.');
    }
    _runtimeInfo = new PanaRuntimeInfo(
      panaVersion: panaPkgVersion.toString(),
      sdkVersion: dartSdkInfo.version.toString(),
      flutterVersions: flutterVersions,
    );
  }

  static Future<ToolEnvironment> create({
    String dartSdkDir,
    String flutterSdkDir,
    String pubCacheDir,
    Map<String, String> environment,
    bool useGlobalDartdoc: false,
  }) async {
    Future<String> resolve(String dir) async {
      if (dir == null) return null;
      return new Directory(dir).resolveSymbolicLinks();
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

    final toolEnv = new ToolEnvironment._(
      resolvedDartSdk,
      resolvedPubCache,
      _join(resolvedDartSdk, 'bin', 'dart'),
      _join(resolvedDartSdk, 'bin', 'pub'),
      _join(resolvedDartSdk, 'bin', 'dartanalyzer'),
      _join(resolvedDartSdk, 'bin', 'dartfmt'),
      _join(resolvedDartSdk, 'bin', 'dartdoc'),
      _join(resolvedFlutterSdk, 'bin', 'flutter'),
      env,
      useGlobalDartdoc,
    );
    await toolEnv._init();
    return toolEnv;
  }

  Future<String> runAnalyzer(
      String packageDir, List<String> dirs, bool usesFlutter) async {
    final originalOptionsFile =
        new File(p.join(packageDir, 'analysis_options.yaml'));
    String originalOptions;
    if (await originalOptionsFile.exists()) {
      originalOptions = await originalOptionsFile.readAsString();
    }
    final customFileName =
        'pana_analysis_options_${new DateTime.now().microsecondsSinceEpoch}.g.yaml';
    final customOptionsFile = new File(p.join(packageDir, customFileName));
    await customOptionsFile
        .writeAsString(customizeAnalysisOptions(originalOptions, usesFlutter));
    final params = ['--options', customOptionsFile.path, '--format', 'machine']
      ..addAll(dirs);
    try {
      final proc = await runProc(
        _dartAnalyzerCmd,
        params,
        environment: _environment,
        workingDirectory: packageDir,
      );
      final String output = proc.stderr;
      if ('\n$output'.contains('\nUnhandled exception:\n')) {
        log.severe('Bad input?');
        log.severe(output);
        var errorMessage =
            '\n$output'.split('\nUnhandled exception:\n')[1].split('\n').first;
        throw new ArgumentError('dartanalyzer exception: $errorMessage');
      }
      return output;
    } finally {
      await customOptionsFile.delete();
    }
  }

  Future<List<String>> filesNeedingFormat(String packageDir) async {
    final dirs = await listFocusDirs(packageDir);
    if (dirs.isEmpty) {
      return const [];
    }
    final files = <String>[];
    for (final dir in dirs) {
      var result = await runProc(
        _dartfmtCmd,
        ['--dry-run', '--set-exit-if-changed', p.join(packageDir, dir)],
        environment: _environment,
      );
      if (result.exitCode == 0) {
        return const [];
      }

      final lines = LineSplitter
          .split(result.stdout)
          .map((file) => p.join(dir, file))
          .toList();
      if (result.exitCode == 1) {
        assert(lines.isNotEmpty);
        files.addAll(lines);
        continue;
      }

      throw [
        "dartfmt on $dir/ failed with exit code ${result.exitCode}",
        result.stderr
      ].join('\n').toString();
    }
    files.sort();
    return files;
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
    return json.decode(result.stdout);
  }

  Future<bool> detectFlutterUse(String packageDir) async {
    final pubspec = new Pubspec.parseFromDir(packageDir);
    return pubspec.usesFlutter;
  }

  Future<ProcessResult> runUpgrade(String packageDir, bool usesFlutter,
      {int retryCount: 3}) async {
    final backup = await _stripPubspecYaml(packageDir);
    ProcessResult result;
    try {
      do {
        retryCount--;

        if (usesFlutter) {
          result = await _execFlutterUpgrade(packageDir, _environment);
        } else {
          result = await _execPubUpgrade(packageDir, _environment);
        }

        if (result.exitCode > 0) {
          var errOutput = result.stderr as String;

          // find cases where retrying is not going to help – and short-circuit
          if (errOutput
              .contains("Could not get versions for flutter from sdk")) {
            log.severe("Flutter SDK required!");
            retryCount = 0;
          } else if (errOutput
              .contains("FINE: Exception type: NoVersionException")) {
            log.severe("Version solve failure");
            retryCount = 0;
          }
        }
      } while (result.exitCode > 0 && retryCount > 0);
    } finally {
      await _restorePubspecYaml(packageDir, backup);
    }
    return result;
  }

  Map<String, String> _globalDartdocEnv() {
    final env = new Map<String, String>.from(_environment);
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
    bool validateLinks: true,
  }) async {
    ProcessResult pr;
    final args = [
      '--output',
      outputDir,
      '--exclude',
      dartdocExcludedLibraries.join(','),
    ];
    if (hostedUrl != null) {
      args.addAll(['--hosted-url', hostedUrl]);
    }
    if (canonicalPrefix != null) {
      args.addAll(['--rel-canonical-prefix', canonicalPrefix]);
    }
    if (!validateLinks) {
      args.add('--no-validate-links');
    }
    if (_useGlobalDartdoc) {
      pr = await runProc(
        _pubCmd,
        ['global', 'run', 'dartdoc']..addAll(args),
        workingDirectory: packageDir,
        environment: _globalDartdocEnv(),
      );
    } else {
      pr = await runProc(
        _dartdocCmd,
        args,
        workingDirectory: packageDir,
        environment: _environment,
      );
    }
    final hasIndexHtml =
        await new File(p.join(outputDir, 'index.html')).exists();
    final hasIndexJson =
        await new File(p.join(outputDir, 'index.json')).exists();
    return new DartdocResult(pr, pr.exitCode == 15, hasIndexHtml, hasIndexJson);
  }

  Future<PackageLocation> getLocation(String package, {String version}) async {
    var args = ['cache', 'add', '--verbose'];
    if (version != null) {
      args.addAll(['--version', version]);
    }
    args.add(package);

    var result = handleProcessErrors(await runProc(
      _pubCmd,
      args,
      environment: _environment,
    ));

    var match = _versionDownloadRegexp.allMatches(result.stdout.trim()).single;
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
    result = handleProcessErrors(await runProc(
      _pubCmd,
      ['cache', 'list'],
      environment: _environment,
    ));

    var map = json.decode(result.stdout) as Map;

    var location =
        map['packages'][package][versionString]['location'] as String;

    if (location == null) {
      throw "Huh? This should be cached!";
    }

    return new PackageLocation(package, versionString, location);
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
    final now = new DateTime.now();
    final backup = new File(
        p.join(packageDir, 'pana-${now.millisecondsSinceEpoch}-pubspec.yaml'));

    final pubspec = new File(p.join(packageDir, 'pubspec.yaml'));
    final original = await pubspec.readAsString();
    final parsed = yamlToJson(original);
    parsed.remove('dev_dependencies');
    parsed.remove('dependency_overrides');

    await pubspec.rename(backup.path);
    await pubspec.writeAsString(json.encode(parsed));

    return backup;
  }

  Future _restorePubspecYaml(String packageDir, File backup) async {
    final pubspec = new File(p.join(packageDir, 'pubspec.yaml'));
    await backup.rename(pubspec.path);
  }
}

class PackageLocation {
  final String package;
  final String version;
  final String location;

  PackageLocation(this.package, this.version, this.location);
}

const dartdocExcludedLibraries = const <String>[
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:developer',
  'dart:io',
  'dart:isolate',
  'dart:math',
  'dart:typed_data',
  'dart:ui',
];

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
  static final _sdkRegexp =
      new RegExp('Dart VM version:\\s([^\\s]+)\\s\\(([^\\)]+)\\) on "(\\w+)"');

  // TODO: parse an actual `DateTime` here. Likely requires using pkg/intl
  final String dateString;
  final String platform;
  final Version version;

  DartSdkInfo._(this.version, this.dateString, this.platform);

  factory DartSdkInfo.parse(String versionOutput) {
    var match = _sdkRegexp.firstMatch(versionOutput);
    var version = new Version.parse(match[1]);
    var dateString = match[2];
    var platform = match[3];

    return new DartSdkInfo._(version, dateString, platform);
  }
}

final _versionDownloadRegexp =
    new RegExp(r"^MSG : (?:Downloading |Already cached )([\w-]+) (.+)$");

const _pubCacheKey = 'PUB_CACHE';
const _pubEnvironmentKey = 'PUB_ENVIRONMENT';

String _join(String path, String binDir, String executable) =>
    path == null ? executable : p.join(path, binDir, executable);
