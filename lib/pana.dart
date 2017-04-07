// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

import 'src/analyzer_output.dart';
import 'src/logging.dart';
import 'src/summary.dart';

export 'src/summary.dart';

String prettyJson(obj) => const JsonEncoder.withIndent(' ').convert(obj).trim();

Future<Summary> inspectPackage(String pkgName,
    {String version, String pubCachePath}) async {
  var versionResult = _handleErrors(await Process.run('dart', ['--version']));

  var sdkVersion = versionResult.stderr.toString().trim();
  log.info("SDK: $sdkVersion");

  log.info("Package: $pkgName");

  Version ver;
  if (version != null) {
    ver = new Version.parse(version);
    log.info("Version: $ver");
  }

  if (pubCachePath != null) {
    log.info("Using .package-cache: ${pubCachePath}");
    var tempDir = new Directory(pubCachePath).resolveSymbolicLinksSync();
    if (tempDir != pubCachePath) {
      throw new ArgumentError([
        "Make sure you resolve symlinks:",
        pubCachePath,
        tempDir
      ].join('\n'));
    }
  }

  log.info("Downloading package...");
  var pkgDir =
      await downloadPkg(pkgName, version: ver, pubCachePath: pubCachePath);
  log.info("Package at ${pkgDir.path}");

  log.info("Checking formatting...");
  var unformattedFiles = filesNeedingFormat(pkgDir.path);

  log.info("Pub upgrade...");
  var summary = await pubUpgrade(pkgDir.path, pubCachePath: pubCachePath);
  log.info("Package version: ${summary.pkgVersion}");

  log.info("Analyzing...");
  var analyzerItems = await pkgAnalyze(pkgDir.path);

  return new Summary(sdkVersion, pkgName, pkgDir.version, summary,
      analyzerItems, unformattedFiles);
}

List<String> filesNeedingFormat(String pkgPath) {
  var result = Process
      .runSync('dartfmt', ['--dry-run', '--set-exit-if-changed', pkgPath]);

  if (result.exitCode == 0) {
    return const [];
  }

  var lines = LineSplitter.split(result.stdout).toList();

  assert(lines.isNotEmpty);

  return lines;
}

Future<Set<AnalyzerOutput>> pkgAnalyze(String pkgPath) async {
  log.info('Running `dartanalyzer`...');
  var proc = await Process.run(
      'dartanalyzer', ['--strong', '--format', 'machine', '.'],
      workingDirectory: pkgPath);

  try {
    return new SplayTreeSet.from(LineSplitter
        .split(proc.stderr)
        .map((s) => AnalyzerOutput.parse(s, projectDir: pkgPath))
        .where((e) => e != null));
  } on ArgumentError {
    // TODO: we should figure out a way to succeed here, right?
    // Or at least do partial results and not blow up
    log.severe("Bad input?");
    log.severe(proc.stderr);
    rethrow;
  }
}

Future<PubSummary> pubUpgrade(String pkgPath, {String pubCachePath}) async {
  var pubEnv = new Map<String, String>.from(_pubEnv);
  if (pubCachePath != null) {
    pubEnv['PUB_CACHE'] = pubCachePath;
  }

  var retryCount = 3;
  ProcessResult result;
  do {
    retryCount--;
    log.info('Running `pub upgrade`...');
    result = await Process.run('pub', ['upgrade', '--verbosity', 'all'],
        workingDirectory: pkgPath, environment: pubEnv);
  } while (result.exitCode != 0 && retryCount > 0);
  return PubSummary.create(
      result.exitCode, result.stdout, result.stderr, pkgPath);
}

Future<PkgInstallInfo> downloadPkg(String pkgName,
    {Version version, String pubCachePath}) async {
  var args = ['cache', 'add', '--verbose'];

  if (version != null) {
    args.addAll(['--version', version.toString()]);
  }

  args.add(pkgName);

  var pubEnv = new Map<String, String>.from(_pubEnv);
  if (pubCachePath != null) {
    pubEnv['PUB_CACHE'] = pubCachePath;
  }

  var result =
      _handleErrors(await Process.run('pub', args, environment: pubEnv));

  var match = _versionDownloadRexexp.allMatches(result.stdout.trim()).single;

  var pkgMatch = match[1];
  assert(pkgMatch == pkgName);

  var versionString = match[2];
  assert(versionString.endsWith('.'));
  while (versionString.endsWith('.')) {
    versionString = versionString.substring(0, versionString.length - 1);
  }

  var downloadedVersion = new Version.parse(versionString);

  if (version != null) {
    assert(downloadedVersion == version);
  }

  // now get all installed packages
  result = _handleErrors(
      await Process.run('pub', ['cache', 'list'], environment: pubEnv));

  var json = JSON.decode(result.stdout) as Map;

  var location = json['packages'][pkgName][versionString]['location'] as String;

  if (location == null) {
    throw "Huh? This should be cached!";
  }

  return new PkgInstallInfo(pkgName, downloadedVersion, location);
}

class PkgInstallInfo {
  final String name;
  final Version version;
  final String path;

  PkgInstallInfo(this.name, this.version, this.path);
}

final _versionDownloadRexexp =
    new RegExp(r"^MSG : (?:Downloading |Already cached )([\w-]+) (.+)$");

const _pubEnv = const <String, String>{'PUB_ENVIRONMENT': 'kevmoo.pkg_clean'};

ProcessResult _handleErrors(ProcessResult result) {
  if (result.exitCode != 0) {
    if (result.exitCode == 69) {
      // could be a pub error. Let's try to parse!
      var lines = LineSplitter
          .split(result.stderr)
          .where((l) => l.startsWith("ERR "))
          .join('\n');
      if (lines.isNotEmpty) {
        throw lines;
      }
    }

    throw "Problem running proc: exit code - " +
        [result.exitCode, result.stdout, result.stderr]
            .map((e) => e.toString().trim())
            .join('<***>');
  }
  return result;
}
