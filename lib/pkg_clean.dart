// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/analyzer_output.dart';
import 'src/logging.dart';
import 'src/summary.dart';

Future<List<AnalyzerOutput>> pkgAnalyze(String pkgPath) async {
  log.info('Running pub upgrade');
  var result = await Process.run(
      'dartanalyzer', ['--strong', '--format', 'machine', '.'],
      workingDirectory: pkgPath);

  return LineSplitter
      .split(result.stderr)
      .map((s) => AnalyzerOutput.parse(s, projectDir: pkgPath))
      .toList();
}

Future<PubSummary> pkgSummary(String pkgPath) async {
  log.info('Running pub upgrade');
  var result = await Process.run('pub', ['upgrade', '--verbosity', 'all'],
      workingDirectory: pkgPath);

  return new PubSummary(result.exitCode, result.stdout, result.stderr);
}

Future<String> downloadPkg(String tempRoot, String pkgName) async {
  var result = await Process.run('pub', ['cache', 'add', pkgName],
      environment: {'PUB_CACHE': tempRoot});

  if (result.exitCode != 0) {
    print(result.stderr.trim());
    print(result.stdout.trim());
    throw 'oops!';
  }

  var dir = new Directory(p.join(tempRoot, 'hosted', 'pub.dartlang.org'));

  var pkgDir = await dir.list().single as Directory;

  return pkgDir.path;
}
