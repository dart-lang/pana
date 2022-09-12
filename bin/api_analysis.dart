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
      'api-analysis', 'A tool for analysing the public API of a dart package.')
    ..addCommand(SummaryCommand())
    ..addCommand(LowerBoundsCommand())
    ..addCommand(LowerBoundsBatchCommand());
  await runner.run(arguments);
}

abstract class ApiAnalysisCommand extends Command {
  @override
  String get usageFooter =>
      'See https://github.com/dart-lang/pana/blob/master/lib/src/api_analysis/README.md for detailed documentation.';

  @override
  String get invocation {
    // Implementation copied from Command with a small change to include argumentsDescription.
    var parents = [name];
    for (var command = parent; command != null; command = command.parent) {
      parents.add(command.name);
    }
    parents.add(runner!.executableName);

    return '${parents.reversed.join(' ')} $argumentsDescription';
  }

  /// A short description of how the arguments should be provided in [invocation].
  String get argumentsDescription;
}

class SummaryCommand extends ApiAnalysisCommand {
  @override
  String get name => 'summary';

  @override
  String get description =>
      'Displays a summary of the public API of a package.';

  @override
  String get argumentsDescription => '<package-path>';

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

class LowerBoundsCommand extends ApiAnalysisCommand {
  @override
  String get name => 'lower-bounds';

  @override
  String get description =>
      'Runs lower bound constraint analysis on a single package.';

  @override
  String get argumentsDescription => '<cache-path> <target-name>';

  LowerBoundsCommand();

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

    // Create a unique temporary directory for the target and the dependencies.
    final tempDir = await Directory(Directory.systemTemp.path)
        .createTemp('lower-bounds-temp');

    final c = http.Client();

    Future<void> cleanUp() async {
      // Clean up the temp directory and the http client.
      await tempDir.delete(recursive: true);
      c.close();
    }

    // Sigterm is not supported on Windows, but sigint is.
    if (!Platform.isWindows) {
      await Isolate.spawn((message) {
        ProcessSignal.sigterm.watch().listen((event) async {
          try {
            await cleanUp();
          } finally {
            exit(0);
          }
        });
      }, null);
    }
    await Isolate.spawn((message) {
      ProcessSignal.sigint.watch().listen((event) async {
        try {
          await cleanUp();
        } finally {
          exit(0);
        }
      });
    }, null);

    try {
      final foundIssues = await lowerBoundConstraintAnalysis(
        targetName: targetName,
        tempPath: path.canonicalize(tempDir.path),
        cachePath: cachePath,
      );

      // Only produce a human-readable report of discovered issues if there is
      // at least one.
      if (foundIssues.isNotEmpty) {
        final report = <String, dynamic>{'issues': []};

        final targetResponse = await retry(
          () => c.get(Uri.parse('https://pub.dev/api/packages/$targetName')),
          retryIf: (e) => e is IOException,
        );
        final targetMetadata = json.decode(targetResponse.body)['latest']
            ['pubspec'] as Map<String, dynamic>;
        final targetHomepage = targetMetadata.containsKey('homepage') &&
                targetMetadata['homepage'] != null
            ? targetMetadata['homepage'] as String
            : '';
        final targetRepository = targetMetadata.containsKey('repository') &&
                targetMetadata['repository'] != null
            ? targetMetadata['repository'] as String
            : '';

        for (final issue in foundIssues) {
          final thisReport = <String, dynamic>{
            'target': {
              'name': targetName,
              'homepage': targetHomepage,
              'repository': targetRepository,
            },
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
                  'Identifier `${issue.identifier}` is a ${issue.kind.toString()}, member of the class `${issue.parentIdentifier!}`';
              break;

            case ParentKind.extensionKind:
              thisReport['identifier']['description'] =
                  'Identifier `${issue.identifier}` is a ${issue.kind.toString()}, member of the extension `${issue.parentIdentifier!}`';
              break;

            case ParentKind.enumKind:
              thisReport['identifier']['description'] =
                  'Identifier `${issue.identifier}` is a ${issue.kind.toString()}, member of the enum `${issue.parentIdentifier!}`';
              break;
          }
          thisReport['identifier']['references'] = issue.references
              .map((reference) => reference.message(''))
              .toList();
          report['issues']!.add(thisReport);
        }

        stdout.writeln(indentedEncoder.convert(report));
      }
    } finally {
      await cleanUp();
    }
  }
}

class LowerBoundsBatchCommand extends ApiAnalysisCommand {
  @override
  String get name => 'lower-bounds-batch';

  @override
  String get description =>
      'Runs lower bound constraint analysis on many packages.';

  @override
  String get argumentsDescription =>
      '<package-number> <process-number> <log-path> <cache-path>';

  LowerBoundsBatchCommand();

  @override
  Future<void> run() async {
    final arguments = argResults!.rest;
    if (arguments.length != 4) {
      throw ArgumentError(
          'This command accepts exactly 4 positional arguments.');
    }

    // Extract positional arguments.
    var packageCountToAnalyze = int.tryParse(arguments[0]);
    final resourceCount = int.tryParse(arguments[1]);
    final logPath = path.canonicalize(arguments[2]);
    final cachePath = path.canonicalize(arguments[3]);

    // Ensure numeric arguments are valid.
    if (packageCountToAnalyze == null ||
        resourceCount == null ||
        packageCountToAnalyze <= 0 ||
        resourceCount <= 0) {
      throw ArgumentError(
          'Failed to parse positional arguments, they must both be positive integers.');
    }

    // Ensure that the log and cache directories exist.
    if (!(await Directory(logPath).exists())) {
      throw ArgumentError(
          'Log path $logPath points to a directory which does not exist.');
    }
    if (!(await Directory(cachePath).exists())) {
      throw ArgumentError(
          'Cache path $cachePath points to a directory which does not exist.');
    }

    // Ensure that api_analysis.dart is at the expected location.
    final packageAnalysisFilePath = path.join(
      Directory.current.path,
      'bin',
      'api_analysis.dart',
    );
    final lowerBoundsCommandName = LowerBoundsCommand().name;
    if (!(await File(packageAnalysisFilePath).exists())) {
      throw ArgumentError(
          'Failed to find file "api_analysis.dart" which is needed for invoking the $lowerBoundsCommandName command, ensure $packageAnalysisFilePath points to this file.');
    }

    final c = http.Client();
    late final List<String> topPackages;
    late final List<String> allPackages;
    try {
      // Fetch the list of top packages.
      // They will already be sorted in descending order of popularity.
      final topPackagesResponse = await retry(
        () => c
            .get(Uri.parse('https://pub.dev/api/package-name-completion-data')),
        retryIf: (e) => e is IOException,
      );
      topPackages = (json.decode(topPackagesResponse.body)['packages'] as List)
          .map((packageName) => packageName as String)
          .toList();

      // Fetch the list of all packages.
      // This is alphabetically sorted.
      final allPackagesResponse = await retry(
        () => c.get(Uri.parse('https://pub.dev/api/package-names')),
        retryIf: (e) => e is IOException,
      );
      allPackages = (json.decode(allPackagesResponse.body)['packages'] as List)
          .map((packageName) => packageName as String)
          .toList();

      // Assuming topPackages is a subset of allPackages, iterate over
      // [allPackages], removing packages from both lists where any of the
      // following is true:
      // - The package is discontinued.
      // - The package's sdk constraint lower bound is < 2.12.0 .
      // - The package's sdk constraint is not satisfied by current version of the sdk.
      // - There are no available (non-redacted) versions of the package.
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
          final packageMetadata = json.decode(packageMetadataResponse.body);

          // The package is discontinued.
          if (packageMetadata['isDiscontinued'] == true) {
            incompatiblePackages.add(packageName);
            return;
          }

          final sdkConstraintStr = packageMetadata['latest']?['pubspec']
              ?['environment']?['sdk'] as String?;

          // Could not find sdk constraint.
          if (sdkConstraintStr == null) {
            incompatiblePackages.add(packageName);
            return;
          }

          // The package does not support null safety.
          final sdkConstraint =
              VersionConstraint.parse(sdkConstraintStr) as VersionRange;
          if (sdkConstraint.min == null ||
              sdkConstraint.min! < Version(2, 12, 0) ||
              !sdkConstraint.allows(currentSdkVersion)) {
            incompatiblePackages.add(packageName);
            return;
          }

          // There are no available (non-redacted) versions of the package.
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

    // Ensure that the indexes up to and including packageCountToAnalyze do not
    // lose their order when ordered lexicographically. This is a useful
    // property to have when browsing logs after analysis is complete.
    String formatIndexForLogfile(int index) {
      final numberOfZeroes = packageCountToAnalyze.toString().length;
      return (index + 1).toString().padLeft(numberOfZeroes, '0');
    }

    // Limit the number of concurrent analysis processes.
    final pool = Pool(resourceCount);

    await Future.wait(packagesToAnalyse
        .getRange(0, packageCountToAnalyze)
        .mapIndexed((targetPackageIndex, targetPackageName) async {
      await pool.withResource(() async {
        stdout.writeln(
            '${DateTime.now().toIso8601String()} Analyzing package $targetPackageName (${targetPackageIndex + 1}/$packageCountToAnalyze)...');

        // Attempt to start the analysis process.
        late final Process process;
        try {
          process = await Process.start(
            Platform.resolvedExecutable,
            [
              'run',
              packageAnalysisFilePath,
              lowerBoundsCommandName,
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

          // Wait for the analysis to complete or time out after 10 minutes.
          final exitCode =
              await process.exitCode.timeout(const Duration(minutes: 10));

          // Capture all output.
          final out = await process.stdout.toList();
          final err = await process.stderr.toList();

          // Save any standard output/standard error returned by the analysis
          // process, but do not write empty log files.
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
