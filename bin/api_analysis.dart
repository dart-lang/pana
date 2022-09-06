// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:pana/src/api_analysis/common.dart';
import 'package:pana/src/api_analysis/kind.dart';
import 'package:pana/src/api_analysis/lower_bound_constraint_analysis.dart';
import 'package:pana/src/api_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:pool/pool.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:retry/retry.dart';

Future<void> main(List<String> arguments) async {
  var runner = CommandRunner(
      'api_analysis', 'A tool for analysing the public API of a dart package.')
    ..addCommand(SummaryCommand())
    ..addCommand(LowerBoundConstraintAnalysisCommand())
    ..addCommand(BatchLBCAnalysisCommand());
  await runner.run(arguments);
}

class SummaryCommand extends Command {
  @override
  final name = 'summary';
  @override
  final description = 'Displays a summary of the public API of a package.';
  @override
  final usage = '''Required positional arguments:
  1) path to a directory containing the package to summarize''';

  SummaryCommand();

  @override
  Future<void> run() async {
    final arguments = argResults!.rest;
    if (arguments.length != 1) {
      throw ArgumentError('Only specify exactly one directory for analysis.');
    }

    final packageLocation = path.canonicalize(arguments[0]);
    if (!await Directory(packageLocation).exists()) {
      throw ArgumentError('Specify a directory for analysis.');
    }
    if (!await File(path.join(packageLocation, 'pubspec.yaml')).exists()) {
      throw StateError('The target directory must contain a package.');
    }
    if (!await File(
            path.join(packageLocation, '.dart_tool', 'package_config.json'))
        .exists()) {
      throw StateError(
          'Run `dart pub get` to fetch dependencies before analysing this package.');
    }

    final session = AnalysisContextCollection(includedPaths: [packageLocation])
        .contextFor(packageLocation)
        .currentSession;
    final packageAnalysisContext = PackageAnalysisContextWithStderr(
      session: session,
      packagePath: packageLocation,
    );

    final packageShape = await summarizePackage(
      context: packageAnalysisContext,
      packagePath: packageLocation,
      normalize: true,
    );

    final packageJson = packageShape.toJson();

    stdout.writeln(indentedEncoder.convert(packageJson));
  }
}

class LowerBoundConstraintAnalysisCommand extends Command {
  @override
  final name = 'lbcanalysis';
  @override
  final description = 'Performs lower bound analysis on a single package.';
  @override
  final usage = '''Required positional arguments:
  1) path to a directory containing package version list cache
  2) name of the package to analyze''';

  LowerBoundConstraintAnalysisCommand();

  @override
  Future<void> run() async {
    final arguments = argResults!.rest;
    if (arguments.length != 2) {
      throw ArgumentError(
          'This command accepts exactly 2 positional arguments.');
    }

    final cachePath = arguments[0];
    final targetName = arguments[1];
    if (!(await Directory(cachePath).exists())) {
      throw ArgumentError(
          'The directory containing package version list cache could not be found.');
    }

    // create a unique temporary directory for the target and the dependencies
    final tempDir = await Directory(Directory.systemTemp.path)
        .createTemp('lbcanalysis_temp');

    final c = http.Client();

    Future<void> cleanUp() async {
      // clean up the temp directory and the http client
      await tempDir.delete(recursive: true);
      c.close();
    }

    // sigterm is not supported on Windows
    if (!Platform.isWindows) {
      await Isolate.spawn((message) {
        ProcessSignal.sigterm.watch().listen((event) async {
          await cleanUp();
          exit(0);
        });
      }, null);
    }

    try {
      final foundIssues = await lowerBoundConstraintAnalysis(
        targetName: targetName,
        tempPath: path.canonicalize(tempDir.path),
        cachePath: cachePath,
      );

      final report = <String, dynamic>{
        'target': {
          'name': targetName,
        },
        'issues': [],
      };

      final targetResponse = await retry(
        () => c.get(Uri.parse('https://pub.dev/api/packages/$targetName')),
        retryIf: (e) => e is IOException,
      );
      final targetMetadata = json.decode(targetResponse.body)['latest']
          ['pubspec'] as Map<String, dynamic>;
      report['target']['homepage'] = targetMetadata.containsKey('homepage') &&
              targetMetadata['homepage'] != null
          ? targetMetadata['homepage'] as String
          : '';
      report['target']['repository'] =
          targetMetadata.containsKey('repository') &&
                  targetMetadata['repository'] != null
              ? targetMetadata['repository'] as String
              : '';

      for (final issue in foundIssues) {
        final thisReport = <String, dynamic>{
          'dependency': {
            'name': issue.dependencyPackageName,
            'constraint': issue.constraint.toString(),
            'documentation': {},
          },
          'identifier': {},
        };
        final dependencyResponse = await retry(
          () => c.get(Uri.parse(
              'https://pub.dev/api/packages/${issue.dependencyPackageName}')),
          retryIf: (e) => e is IOException,
        );
        final dependencyMetadata =
            json.decode(dependencyResponse.body)['latest']['pubspec']
                as Map<String, dynamic>;
        thisReport['dependency']['homepage'] =
            dependencyMetadata.containsKey('homepage')
                ? dependencyMetadata['homepage'] as String
                : '';
        thisReport['dependency']['repository'] =
            dependencyMetadata.containsKey('repository')
                ? dependencyMetadata['repository'] as String
                : '';
        thisReport['dependency']['documentation']['lowestAllowedVersion'] =
            'https://pub.dev/documentation/${issue.dependencyPackageName}/${issue.lowestVersion}/';
        thisReport['dependency']['documentation']['installedVersion'] =
            'https://pub.dev/documentation/${issue.dependencyPackageName}/${issue.currentVersion}/';

        thisReport['identifier']['name'] = issue.identifier;

        switch (issue.parentKind) {
          case null:
            thisReport['identifier']['description'] =
                'Identifier `${issue.identifier}` is a top-level ${issue.kind.toString()}';
            break;

          case ParentKind.classKind:
            thisReport['identifier']['description'] =
                'Identifier `${issue.identifier}` is a ${issue.kind.toString()}, member of the class `${issue.parentName!}`';
            break;

          case ParentKind.extensionKind:
            thisReport['identifier']['description'] =
                'Identifier `${issue.identifier}` is a ${issue.kind.toString()}, member of the extension `${issue.parentName!}`';
            break;

          case ParentKind.enumKind:
            thisReport['identifier']['description'] =
                'Identifier `${issue.identifier}` is a ${issue.kind.toString()}, member of the enum `${issue.parentName!}`';
            break;
        }
        thisReport['identifier']['references'] =
            issue.references.map((reference) => reference.message('')).toList();
        report['issues']!.add(thisReport);
      }

      stdout.writeln(indentedEncoder.convert(report));
    } finally {
      await cleanUp();
    }
  }
}

class BatchLBCAnalysisCommand extends Command {
  @override
  final name = 'batchlbca';
  @override
  final description = 'Runs lower bound constraint analysis on many packages.';
  @override
  final usage = '''Required positional arguments:
  1) number of packages to analyze
  2) number of parallel analysis processes to run
  3) path to the directory where log files will be saved
  4) path to a directory containing package version list cache''';

  BatchLBCAnalysisCommand();

  @override
  Future<void> run() async {
    final arguments = argResults!.rest;
    if (arguments.length != 4) {
      throw ArgumentError(
          'This command accepts exactly 4 positional arguments.');
    }

    // extract positional arguments
    var packageCountToAnalyze = int.tryParse(arguments[0]);
    final resourceCount = int.tryParse(arguments[1]);
    final logPath = path.canonicalize(arguments[2]);
    final cachePath = path.canonicalize(arguments[3]);

    // ensure numeric arguments are valid
    if (packageCountToAnalyze == null ||
        resourceCount == null ||
        packageCountToAnalyze <= 0 ||
        resourceCount <= 0) {
      throw ArgumentError(
          'Failed to parse positional arguments, they must both be positive integers.');
    }

    // ensure that the log and cache directories exist
    if (!(await Directory(logPath).exists())) {
      throw ArgumentError(
          'Log path $logPath points to a directory which does not exist.');
    }
    if (!(await Directory(cachePath).exists())) {
      throw ArgumentError(
          'Cache path $cachePath points to a directory which does not exist.');
    }

    // ensure that api_analysis.dart is at the expected location
    final packageAnalysisFilePath = path.join(
      Directory.current.path,
      'bin',
      'api_analysis.dart',
    );
    final lbcAnalysisCommandName = LowerBoundConstraintAnalysisCommand().name;
    if (!(await File(packageAnalysisFilePath).exists())) {
      throw ArgumentError(
          'Failed to find file "api_analysis.dart" which is needed for invoking the $lbcAnalysisCommandName command, ensure $packageAnalysisFilePath points to this file.');
    }

    final c = http.Client();
    late final List<String> topPackages;
    late final List<String> allPackages;
    try {
      // fetch the list of top packages from the pub endpoint
      // they will already be sorted in descending order of popularity
      final topPackagesResponse = await retry(
        () => c
            .get(Uri.parse('https://pub.dev/api/package-name-completion-data')),
        retryIf: (e) => e is IOException,
      );
      topPackages = (json.decode(topPackagesResponse.body)['packages'] as List)
          .map((packageName) => packageName as String)
          .toList();

      // fetch the list of all package names
      // this is alphabetically sorted
      final allPackagesResponse = await retry(
        () => c.get(Uri.parse('https://pub.dev/api/package-names')),
        retryIf: (e) => e is IOException,
      );
      allPackages = (json.decode(allPackagesResponse.body)['packages'] as List)
          .map((packageName) => packageName as String)
          .toList();

      // assuming topPackages is a subset of allPackages, iterate over allPackages,
      // removing packages from both lists where either of the following is true:
      // - lower bound sdk constraint is < 2.12.0
      // - sdk constraint is not satisfied by current version of the sdk
      final incompatiblePackages = <String>[];
      final pool = Pool(16);
      final currentSdkVersion =
          Version.parse(Platform.version.split(' ').first);
      await Future.wait(allPackages.map((packageName) async {
        await pool.withResource(() async {
          final packageMetadataResponse = await retry(
            () => c.get(Uri.parse('https://pub.dev/api/packages/$packageName')),
            retryIf: (e) => e is IOException,
          );
          final sdkConstraintStr =
              json.decode(packageMetadataResponse.body)?['latest']?['pubspec']
                  ?['environment']?['sdk'] as String?;

          // could not determine sdk constraint
          if (sdkConstraintStr == null) {
            incompatiblePackages.add(packageName);
            return;
          }

          final sdkConstraint =
              VersionConstraint.parse(sdkConstraintStr) as VersionRange;
          if (sdkConstraint.min == null ||
              sdkConstraint.min! < Version(2, 12, 0) ||
              !sdkConstraint.allows(currentSdkVersion)) {
            incompatiblePackages.add(packageName);
            return;
          }

          // if there are no available versions of this package, do not analyse it
          if ((await fetchSortedPackageVersionList(
            packageName: packageName,
            cachePath: cachePath,
          ))
              .isEmpty) {
            incompatiblePackages.add(packageName);
            return;
          }
        });
      }));
      topPackages.removeWhere(incompatiblePackages.contains);
      allPackages.removeWhere(incompatiblePackages.contains);
    } finally {
      c.close();
    }

    if (packageCountToAnalyze > allPackages.length) {
      stderr.writeln(
          'Provided package count to analyse is too high, analysing all ${allPackages.length} available packages instead.');
      packageCountToAnalyze = allPackages.length;
    }
    final packagesToAnalyse =
        packageCountToAnalyze > topPackages.length ? allPackages : topPackages;

    // ensures that the indexes up to and including packageCountToAnalyze do not
    // lose their order when ordered lexicographically
    String formatIndexForLogfile(int index) {
      final numberOfZeroes = packageCountToAnalyze.toString().length;
      return (index + 1).toString().padLeft(numberOfZeroes, '0');
    }

    final pool = Pool(resourceCount);

    await Future.wait(packagesToAnalyse
        .getRange(0, packageCountToAnalyze)
        .mapIndexed((targetPackageIndex, targetPackageName) async {
      await pool.withResource(() async {
        stdout.writeln(
            '${DateTime.now().toIso8601String()} Analyzing package $targetPackageName (${targetPackageIndex + 1}/$packageCountToAnalyze)...');

        late final Process process;
        try {
          process = await Process.start(
            Platform.resolvedExecutable,
            [
              'run',
              packageAnalysisFilePath,
              lbcAnalysisCommandName,
              cachePath,
              targetPackageName,
            ],
          );
        } catch (e) {
          stderr.writeln(
              'Failed to start analysis process on package $targetPackageName with error $e.');
          return;
        }

        try {
          final logPathPrefix = path.join(logPath,
              '${formatIndexForLogfile(targetPackageIndex)} $targetPackageName');

          // wait for the analysis to complete or time out after 10 minutes
          final exitCode =
              await process.exitCode.timeout(const Duration(minutes: 10));

          // capture all output
          final out = await process.stdout.toList();
          final err = await process.stderr.toList();

          // do not write empty log files
          if (out.isNotEmpty) {
            final stdoutLog = File('$logPathPrefix stdout.txt').openWrite();
            out.forEach(stdoutLog.add);
            await stdoutLog.flush();
            await stdoutLog.close();
          }
          if (err.isNotEmpty) {
            final stderrLog = File('$logPathPrefix stderr.txt').openWrite();
            err.forEach(stderrLog.add);
            await stderrLog.flush();
            await stderrLog.close();
          }

          if (exitCode != 0) {
            stderr.writeln(
                'Analysis of package $targetPackageName completed with a non-zero exit code.');
          }
        } on TimeoutException {
          stderr.writeln(
              'Timed out while running analysis on package $targetPackageName.');
          process.kill();
        }
      });
    }));
  }
}
