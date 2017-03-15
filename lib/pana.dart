// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'src/analyzer_output.dart';
import 'src/logging.dart';
import 'src/summary.dart';

export 'src/summary.dart';

String prettyJson(obj) => const JsonEncoder.withIndent(' ').convert(obj).trim();

Future<Summary> doIt(String pkgName, {String version}) async {
  log.info("Package: $pkgName");

  Version ver;
  if (version != null) {
    ver = new Version.parse(version);
  }

  if (ver != null) {
    log.info("Version: $ver");
  }

  log.fine('Created tmp dir...');
  var tempDir = Directory.systemTemp
      .createTempSync('pana.${new DateTime.now().millisecondsSinceEpoch}.');

  // Critical to make sure analyzer paths align well
  var tempPath = await tempDir.resolveSymbolicLinks();

  log.fine('Temp dir: $tempPath');

  var data = <String, Object>{'package': pkgName};

  try {
    log.info("Downloading package...");
    var pkgDir = await downloadPkg(tempPath, pkgName, version: ver);

    var summary = await pkgSummary(pkgDir);

    data['pub'] = summary;

    var thing = await pkgAnalyze(pkgDir);

    return new Summary(pkgName, summary, thing);
  } finally {
    log.fine("Deleting temp dir: $tempPath");
    await tempDir.delete(recursive: true);
  }
}

Future<List<AnalyzerOutput>> pkgAnalyze(String pkgPath) async {
  log.info('Running `dartanalyzer`...');
  var result = await Process.run(
      'dartanalyzer', ['--strong', '--format', 'machine', '.'],
      workingDirectory: pkgPath);

  return LineSplitter
      .split(result.stderr)
      .map((s) => AnalyzerOutput.parse(s, projectDir: pkgPath))
      .toList();
}

Future<PubSummary> pkgSummary(String pkgPath) async {
  log.info('Running `pub upgrade`...');
  var result = await Process.run('pub', ['upgrade', '--verbosity', 'all'],
      workingDirectory: pkgPath);

  return new PubSummary(result.exitCode, result.stdout, result.stderr);
}

Future<String> downloadPkg(String tempRoot, String pkgName,
    {Version version}) async {
  var args = ['cache', 'add'];

  if (version != null) {
    args.addAll(['--version', version.toString()]);
  }

  args.add(pkgName);

  var result =
      await Process.run('pub', args, environment: {'PUB_CACHE': tempRoot});

  if (result.exitCode != 0) {
    print(result.stderr.trim());
    print(result.stdout.trim());
    throw 'oops!';
  }

  var dir = new Directory(p.join(tempRoot, 'hosted', 'pub.dartlang.org'));

  var pkgDir = await dir.list().single as Directory;

  return pkgDir.path;
}
