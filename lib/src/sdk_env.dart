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
import 'sdk_info.dart';
import 'utils.dart';

class DartSdk implements DartSdkInfo {
  final String sdkDir;
  final Map<String, String> _environment;
  final String _dartAnalyzerCmd;
  final String _dartfmtCmd;
  final String _pubCmd;
  final String dateString;
  final String platform;
  final Version version;

  DartSdk._(this.sdkDir, this._environment, this.version, this.dateString,
      this.platform)
      : _dartAnalyzerCmd = _join(sdkDir, 'bin', 'dartanalyzer'),
        _dartfmtCmd = _join(sdkDir, 'bin', 'dartfmt'),
        _pubCmd = _join(sdkDir, 'bin', 'pub');

  static Future<DartSdk> create(
      {String sdkDir, Map<String, String> environment}) async {
    sdkDir ??= cli.getSdkPath();
    environment ??= {};

    var dartCmd = _join(sdkDir, 'bin', 'dart');

    var r = handleProcessErrors(
        await runProc(dartCmd, ['--version'], environment: environment));
    var versionString = r.stderr.toString().trim();

    var info = new DartSdkInfo.parse(versionString);

    return new DartSdk._(
        sdkDir, environment, info.version, info.dateString, info.platform);
  }

  Future<ProcessResult> runAnalyzer(
      String packageDir, List<String> dirs, bool isFlutter) async {
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
        .writeAsString(customizeAnalysisOptions(originalOptions, isFlutter));
    final params = ['--options', customOptionsFile.path, '--format', 'machine']
      ..addAll(dirs);
    try {
      return await runProc(
        _dartAnalyzerCmd,
        params,
        environment: _environment,
        workingDirectory: packageDir,
      );
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

  Future<ProcessResult> _execUpgrade(
      String packageDir, Map<String, String> environment) {
    return runProc(
      _pubCmd,
      ['upgrade', '--verbosity', 'io', '--no-precompile'],
      workingDirectory: packageDir,
      environment: environment,
    );
  }
}

class FlutterSdk {
  final String _flutterBin;

  FlutterSdk({String sdkDir}) : _flutterBin = _join(sdkDir, 'bin', 'flutter');

  Future<ProcessResult> _execUpgrade(
          String packageDir, Map<String, String> environment) =>
      runProc(
        _flutterBin,
        ['packages', 'pub', 'upgrade', '--verbosity', 'io', '--no-precompile'],
        workingDirectory: packageDir,
        environment: environment,
      );

  Future<Map<String, Object>> getVersion() async {
    var result = await runProc(_flutterBin, ['--version', '--machine']);
    assert(result.exitCode == 0);
    return JSON.decode(result.stdout);
  }
}

class PubEnvironment {
  final DartSdk dartSdk;
  final FlutterSdk flutterSdk;
  final String pubCacheDir;
  final Map<String, String> _environment = {};

  PubEnvironment(this.dartSdk, {FlutterSdk flutterSdk, this.pubCacheDir})
      : this.flutterSdk = flutterSdk ?? new FlutterSdk() {
    _environment.addAll(this.dartSdk._environment);
    if (!_environment.containsKey(_pubEnvironmentKey)) {
      // Then do the standard behavior. Extract the current value, if any,
      // and append the default value

      var pubEnvironment = <String>[];

      var currentEnv = Platform.environment[_pubEnvironmentKey];

      if (currentEnv != null) {
        pubEnvironment.addAll(currentEnv
                .split(
                    ':') // if there are many values, they should be separated by `:`
                .map((v) => v.trim()) // don't want whitespace
                .where((v) => v.isNotEmpty) // don't want empty values
            );
      }

      pubEnvironment.add('bot.pkg_pana');

      _environment[_pubEnvironmentKey] = pubEnvironment.join(':');
    }
    if (pubCacheDir != null) {
      var resolvedDir = new Directory(pubCacheDir).resolveSymbolicLinksSync();
      if (resolvedDir != pubCacheDir) {
        throw new ArgumentError([
          "Make sure you resolve symlinks:",
          pubCacheDir,
          resolvedDir
        ].join('\n'));
      }
      _environment['PUB_CACHE'] = pubCacheDir;
    }
  }

  Future<ProcessResult> runUpgrade(String packageDir, bool isFlutter,
      {int retryCount: 3}) async {
    ProcessResult result;
    do {
      retryCount--;

      if (isFlutter) {
        result = await flutterSdk._execUpgrade(packageDir, _environment);
      } else {
        result = await dartSdk._execUpgrade(packageDir, _environment);
      }

      if (result.exitCode > 0) {
        var errOutput = result.stderr as String;

        // find cases where retrying is not going to help – and short-circuit
        if (errOutput.contains("Could not get versions for flutter from sdk")) {
          log.severe("Flutter SDK required!");
          retryCount = 0;
        } else if (errOutput
            .contains("FINE: Exception type: NoVersionException")) {
          log.severe("Version solve failure");
          retryCount = 0;
        }
      }
    } while (result.exitCode > 0 && retryCount > 0);
    return result;
  }

  Future<PackageLocation> getLocation(String package, {String version}) async {
    var args = ['cache', 'add', '--verbose'];
    if (version != null) {
      args.addAll(['--version', version]);
    }
    args.add(package);

    var result = handleProcessErrors(await runProc(
      dartSdk._pubCmd,
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
      dartSdk._pubCmd,
      ['cache', 'list'],
      environment: _environment,
    ));

    var json = JSON.decode(result.stdout) as Map;

    var location =
        json['packages'][package][versionString]['location'] as String;

    if (location == null) {
      throw "Huh? This should be cached!";
    }

    return new PackageLocation(package, versionString, location);
  }

  ProcessResult listPackageDirsSync(String packageDir, bool useFlutter) {
    if (useFlutter) {
      // flutter env
      return runProcSync(
        flutterSdk._flutterBin,
        ['packages', 'pub', 'list-package-dirs'],
        workingDirectory: packageDir,
        environment: _environment,
      );
    } else {
      // normal pub
      return runProcSync(
        dartSdk._pubCmd,
        ['list-package-dirs'],
        workingDirectory: packageDir,
        environment: _environment,
      );
    }
  }

  /// Removes the dev_dependencies from the pubspec.yaml
  /// Returns the backup file with the original content.
  Future<File> stripPubspecYaml(String packageDir) async {
    final now = new DateTime.now();
    final backup = new File(
        p.join(packageDir, 'pana-${now.millisecondsSinceEpoch}-pubspec.yaml'));

    final pubspec = new File(p.join(packageDir, 'pubspec.yaml'));
    final original = await pubspec.readAsString();
    final parsed = yamlToJson(original);
    parsed.remove('dev_dependencies');
    parsed.remove('dependency_overrides');

    await pubspec.rename(backup.path);
    await pubspec.writeAsString(JSON.encode(parsed));

    return backup;
  }

  Future restorePubspecYaml(String packageDir, File backup) async {
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

final _versionDownloadRegexp =
    new RegExp(r"^MSG : (?:Downloading |Already cached )([\w-]+) (.+)$");

const _pubEnvironmentKey = 'PUB_ENVIRONMENT';

String _join(String path, String binDir, String executable) =>
    path == null ? executable : p.join(path, binDir, executable);
