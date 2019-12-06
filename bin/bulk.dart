// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Example uses:
///   bulk analyze --output output-dir-1 pkg1 pkg2 pkg3
///   bulk analyze --dart-sdk /path/to/sdk --output output-dir-2 pkg1 pkg2 pkg3
///   bulk summary output-dir-1 output-dir-2

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:pana/pana.dart';
import 'package:pool/pool.dart';

final _jsonEncoder = const JsonEncoder.withIndent('  ');

Future<void> main(List<String> args) async {
  final runner = CommandRunner('bulk', 'Pana bulk processing')
    ..addCommand(AnalyzeCommand())
    ..addCommand(SummaryCommand());
  await runner.run(args);
}

class AnalyzeCommand extends Command {
  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyzes multiple packages';

  AnalyzeCommand() {
    argParser
      ..addOption('concurrency',
          defaultsTo: '1', help: 'The concurrent execution of the analyis.')
      ..addOption('dart-sdk', help: 'The directory of the Dart SDK.')
      ..addOption('flutter-sdk', help: 'The directory of the Flutter SDK.')
      ..addOption('packages-list',
          help: 'The input file with the list of packages.')
      ..addOption('output',
          help: 'The output directory to store the per-package results.')
      ..addFlag('force',
          help:
              'Re-do analysis for packages where the output file already exists.');
  }

  @override
  Future<void> run() async {
    final concurrency = int.parse(argResults['concurrency'] as String ?? '1');
    final pool = Pool(concurrency);
    final force = argResults['force'] as bool;

    final packages = <String>{};
    packages.addAll(argResults.rest);

    final packagesListFileName = argResults['packages-list'] as String;
    if (packagesListFileName != null) {
      final file = File(packagesListFileName);
      if (!(await file.exists())) {
        print('Packages list file $packagesListFileName does not exists.');
        exit(1);
      }
      final lines = await file.readAsLines();
      packages.addAll(lines.where((l) => l.isNotEmpty));
    }

    if (packages.isEmpty) {
      print('No package to analyze.');
      exit(0);
    }

    final outputDirPath = argResults['output'] as String;
    if (outputDirPath == null) {
      print('Output directory must be specified.');
      exit(1);
    }
    final outputDir = Directory(outputDirPath);
    await outputDir.create(recursive: true);

    final dartSdkDir = argResults['dart-sdk'] as String;
    if (dartSdkDir == null) {
      print('Using default Dart SDK.');
    }
    final flutterSdkDir = argResults['flutter-sdk'] as String;
    if (flutterSdkDir == null) {
      print('Using default Flutter SDK.');
    }

    final tmpDir = await Directory.systemTemp.createTemp('pana-bulk-');
    try {
      final pubCacheTmp = await tmpDir.createTemp('pub-cache');
      final pubCacheDir = await pubCacheTmp.resolveSymbolicLinks();

      final toolEnv = await ToolEnvironment.create(
        dartSdkDir: dartSdkDir,
        flutterSdkDir: flutterSdkDir,
        pubCacheDir: pubCacheDir,
      );

      final analyzer = PackageAnalyzer(toolEnv);
      final futures = <Future>[];
      for (final package in packages) {
        final outputFile = File('${outputDir.path}/$package.json');
        if (!force && outputFile.existsSync() && outputFile.lengthSync() > 0) {
          continue;
        }

        final f = pool.withResource(() async {
          print('Analyzing $package...');
          try {
            final summary = await analyzer.inspectPackage(
              package,
              options: InspectOptions(verbosity: Verbosity.compact),
            );
            await outputFile
                .writeAsString(_jsonEncoder.convert(summary.toJson()));
          } catch (e, st) {
            stdout.writeln('Analyzing $package failed: $e.');
            stdout.writeln('Stacktrace:\n$st');
          }
        });
        futures.add(f);
      }
      await Future.wait(futures);
    } finally {
      await tmpDir.delete(recursive: true);
    }
  }
}

class SummaryCommand extends Command {
  @override
  String get name => 'summary';

  @override
  String get description => 'Aggregates the pana results from a directory.';

  @override
  Future<void> run() async {
    final directories = <String>[];
    directories.addAll(argResults.rest);

    BatchStats previous;
    final report = <String, dynamic>{};
    for (final directory in directories) {
      final files = Directory(directory)
          .list()
          .where((fse) => fse is File && fse.path.endsWith('.json'));
      final batchStats = BatchStats();
      await for (final file in files) {
        final jsonContent = await (file as File).readAsString();
        final summary =
            Summary.fromJson(json.decode(jsonContent) as Map<String, dynamic>);
        batchStats.add(summary);
      }

      final diff = previous == null ? null : BatchDiff(previous, batchStats);

      report[directory] = {
        'stats': batchStats.toJson(),
        'diff': diff?.toJson(),
      };

      previous = batchStats;
    }

    print(_jsonEncoder.convert(report));
  }
}

class BatchStats {
  final _processFailureList = <String>[];
  final _processSuccessList = <String>[];
  int _healthErrorSum = 0;
  int _healthWarningSum = 0;
  int _healthHintSum = 0;
  final _noErrorList = <String>[];
  final _noWarningList = <String>[];
  final _noHintList = <String>[];

  void add(Summary summary) {
    if (summary.health.anyProcessFailed) {
      _processFailureList.add(summary.packageName);
    } else {
      _processSuccessList.add(summary.packageName);
      _healthErrorSum += summary.health.analyzerErrorCount;
      _healthWarningSum += summary.health.analyzerWarningCount;
      _healthHintSum += summary.health.analyzerHintCount;
      final hasError = summary.health.analyzerErrorCount > 0;
      final hasWarning = hasError || summary.health.analyzerWarningCount > 0;
      final hasHint = hasWarning || summary.health.analyzerHintCount > 0;
      if (!hasError) {
        _noErrorList.add(summary.packageName);
      }
      if (!hasWarning) {
        _noWarningList.add(summary.packageName);
      }
      if (!hasHint) {
        _noHintList.add(summary.packageName);
      }
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'processFailureCount': _processFailureList.length,
        'processSuccessCount': _processSuccessList.length,
        'healthErrorSum': _healthErrorSum,
        'healthWarningSum': _healthWarningSum,
        'healthHintSum': _healthHintSum,
        'noErrorCount': _noErrorList.length,
        'noWarningCount': _noWarningList.length,
        'noHintCount': _noHintList.length,
      };
}

class BatchDiff {
  final _processFixed = <String>[];
  final _processFailed = <String>[];
  int _healthErrorsDiff = 0;
  int _healthWarningsDiff = 0;
  int _healthHintsDiff = 0;
  final _errorsAppeared = <String>[];
  final _errorsDisappeared = <String>[];
  final _warningAppeared = <String>[];
  final _warningDisappeared = <String>[];
  final _hintsAppeared = <String>[];
  final _hintsDisappeared = <String>[];

  BatchDiff(BatchStats prev, BatchStats next) {
    _diff(prev._processSuccessList, next._processSuccessList, _processFixed);
    _diff(prev._processFailureList, next._processFailureList, _processFailed);
    _healthErrorsDiff = next._healthErrorSum - prev._healthErrorSum;
    _healthWarningsDiff = next._healthWarningSum - prev._healthWarningSum;
    _healthHintsDiff = next._healthHintSum - prev._healthHintSum;
    _diff(prev._noErrorList, next._noErrorList, _errorsDisappeared);
    _diff(next._noErrorList, prev._noErrorList, _errorsAppeared);
    _diff(prev._noWarningList, next._noWarningList, _warningDisappeared);
    _diff(next._noWarningList, prev._noWarningList, _warningAppeared);
    _diff(prev._noHintList, next._noHintList, _hintsDisappeared);
    _diff(next._noHintList, prev._noHintList, _hintsAppeared);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'processFixed': _ifNotEmpty(_processFixed),
      'processFailed': _ifNotEmpty(_processFailed),
      'healthErrorsDiff': _notZero(_healthErrorsDiff),
      'healthWarningsDiff': _notZero(_healthWarningsDiff),
      'healthHintsDiff': _notZero(_healthHintsDiff),
      'errorsAppeared': _ifNotEmpty(_errorsAppeared),
      'errorsDissppeared': _ifNotEmpty(_errorsDisappeared),
      'warningsAppeared': _ifNotEmpty(_warningAppeared),
      'warningsDisappeared': _ifNotEmpty(_warningDisappeared),
      'hintsAppeared': _ifNotEmpty(_hintsAppeared),
      'hintsDissppeared': _ifNotEmpty(_hintsDisappeared),
    }..removeWhere((k, v) => v == null);
  }

  void _diff(
      Iterable<String> prev, Iterable<String> next, List<String> target) {
    target.addAll(next.toSet()..removeAll(prev));
    target.sort();
  }

  List _ifNotEmpty(List list) {
    return list.isEmpty ? null : list;
  }

  int _notZero(int value) {
    return value == 0 ? null : value;
  }
}
