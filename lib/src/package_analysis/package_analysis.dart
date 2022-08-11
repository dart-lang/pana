import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:path/path.dart' as path;
import 'package:pool/pool.dart';
import 'package:retry/retry.dart';

import 'common.dart';
import 'lower_bound_constraint_analysis.dart';
import 'summary.dart';

Future<void> main(List<String> arguments) async {
  var runner = CommandRunner('package_analysis',
      'A tool for analysing the public API of a dart package.')
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
    );

    final packageJson = packageShape.toJson();

    print(indentedEncoder.convert(packageJson));
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
    final targetVersions = await fetchSortedPackageVersionList(
      packageName: targetName,
      cachePath: cachePath,
    );

    // create a unique temporary directory for the target and the dependencies
    final tempDir = await Directory(Directory.systemTemp.path)
        .createTemp('lbcanalysis_temp');
    final baseFolder = path.canonicalize(tempDir.path);

    final dummyPath = path.join(baseFolder, 'target');
    final dependencyFolder = path.join(baseFolder, 'dependencies');

    try {
      await fetchUsingDummyPackage(
        name: targetName,
        version: targetVersions.last,
        destination: dummyPath,
        wipeTarget: true,
      );
    } on ProcessException catch (exception) {
      await tempDir.delete(recursive: true);
      throw AnalysisException(
          'Failed to download target package $targetName with error code ${exception.errorCode}: ${exception.message}');
    }

    // create session for analysing the package being searched for issues (the target package)
    final collection = AnalysisContextCollection(includedPaths: [dummyPath]);
    final dummyPackageAnalysisContext = PackageAnalysisContextWithStderr(
      session: collection.contextFor(dummyPath).currentSession,
      packagePath: dummyPath,
      targetPackageName: targetName,
    );

    // if there are no dependencies, there is nothing to analyze
    if (dummyPackageAnalysisContext.dependencies.isEmpty) {
      return;
    }

    final dependencySummaries = <String, PackageShape>{};

    // iterate over each dependency of the target package and for each one:
    // - determine minimum allowed version
    // - determine installed (current/actual) version
    // - download minimum allowed version
    // - produce a summary of the minimum allowed version
    for (final dependencyEntry
    in dummyPackageAnalysisContext.dependencies.entries) {
      final dependencyName = dependencyEntry.key;
      final dependencyVersionConstraint = dependencyEntry.value.version;
      final dependencyDestination =
      path.join(dependencyFolder, '${dependencyName}_dummy');

      // determine the minimum allowed version of this dependency as allowed
      // by the constraints imposed by the target package
      final allVersions = await fetchSortedPackageVersionList(
        packageName: dependencyName,
        cachePath: cachePath,
      );
      final minVersion =
      allVersions.firstWhereOrNull(dependencyVersionConstraint.allows);

      if (minVersion == null) {
        dummyPackageAnalysisContext.warning(
            'Skipping dependency $dependencyName, could not determine minimum allowed version.');
        continue;
      }

      // download minimum allowed version of dependency
      try {
        await fetchUsingDummyPackage(
          name: dependencyName,
          version: minVersion,
          destination: dependencyDestination,
          wipeTarget: true,
        );
      } on ProcessException catch (exception) {
        dummyPackageAnalysisContext.warning(
            'Skipping dependency $dependencyName of target package $targetName, failed to download it with error code ${exception.errorCode}: ${exception.message}');
        continue;
      }

      // create session for producing a summary of this dependency
      final collection = AnalysisContextCollection(includedPaths: [
        dependencyDestination,
      ]);
      final dependencyPackageAnalysisContext = PackageAnalysisContextWithStderr(
        session: collection.contextFor(dependencyDestination).currentSession,
        packagePath: dependencyDestination,
      );

      // produce a summary of the minimum version of this dependency and store it
      dependencySummaries[dependencyName] = await summarizePackage(
        context: dependencyPackageAnalysisContext,
        packagePath:
        dependencyPackageAnalysisContext.findPackagePath(dependencyName),
      );
    }

    final foundIssues = await lowerBoundConstraintAnalysis(
      context: dummyPackageAnalysisContext,
      dependencySummaries: dependencySummaries,
    );

    for (final issue in foundIssues) {
      dummyPackageAnalysisContext.warning(
          'Symbol ${issue.kind} ${issue.identifier} with parent ${issue.className} is used in $targetName but could not be found in dependency ${issue.dependencyPackageName} version ${issue.lowestVersion}, which is allowed by constraint ${issue.constraint}.');
      for (final reference in issue.references) {
        dummyPackageAnalysisContext.warning(reference.message(''));
      }
    }

    // clean up by deleting the temp directory
    await tempDir.delete(recursive: true);
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
    final packageCountToAnalyze = int.tryParse(arguments[0]);
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

    // ensure that package_analysis.dart is at the expected location
    final packageAnalysisFilePath = path.join(
      Directory.current.path,
      'lib',
      'src',
      'package_analysis',
      'package_analysis.dart',
    );
    final lbcAnalysisCommandName = LowerBoundConstraintAnalysisCommand().name;
    if (!(await File(packageAnalysisFilePath).exists())) {
      throw ArgumentError(
          'Failed to find file "package_analysis.dart" which is needed for invoking the $lbcAnalysisCommandName command, ensure $packageAnalysisFilePath points to this file.');
    }

    // fetch the list of top packages from the pub endpoint
    // (they will already be sorted in descending order of popularity)
    final c = http.Client();
    late final List<String> topPackages;
    try {
      final topPackagesResponse = await retry(
        () => c
            .get(Uri.parse('https://pub.dev/api/package-name-completion-data')),
        retryIf: (e) => e is IOException,
      );
      topPackages = (json.decode(topPackagesResponse.body)['packages'] as List)
          .map((packageName) => packageName as String)
          .toList();
    } finally {
      c.close();
    }

    if (packageCountToAnalyze > topPackages.length) {
      throw ArgumentError(
          'Number of packages to analyze is too high, the maximum supported value is ${topPackages.length}.');
    }

    // ensures that the indexes up to and including packageCountToAnalyze do not
    // lose their order when ordered lexicographically
    String formatIndexForLogfile(int index) {
      final numberOfZeroes = packageCountToAnalyze.toString().length;
      return (index + 1).toString().padLeft(numberOfZeroes, '0');
    }

    final pool = Pool(resourceCount);

    await Future.wait(topPackages
        .getRange(0, packageCountToAnalyze)
        .mapIndexed((targetPackageIndex, targetPackageName) async {
      await pool.withResource(() async {
        print(
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
          stderr.write(
              'Failed to start analysis process on package $targetPackageName with error $e.');
          return;
        }

        try {
          final logPathPrefix = path.join(logPath,
              '${formatIndexForLogfile(targetPackageIndex)} $targetPackageName');
          final stdoutLog = File('$logPathPrefix stdout.txt').openWrite();
          final stderrLog = File('$logPathPrefix stderr.txt').openWrite();

          // wait for the analysis to complete or time out after 10 minutes
          final exitCode =
              await process.exitCode.timeout(const Duration(minutes: 10));

          // capture all output in log files
          await Future.wait([
            process.stdout.pipe(stdoutLog),
            process.stderr.pipe(stderrLog),
          ]);

          if (exitCode != 0) {
            stderr.write(
                'Analysis of package $targetPackageName completed with a non-zero exit code.');
          }
        } catch (e) {
          stderr.write(
              'Failed to run analysis on package $targetPackageName with error $e.');
          process.kill();
        }
      });
    }));
  }
}

@internal
class PackageAnalysisContextWithStderr extends PackageAnalysisContext {
  PackageAnalysisContextWithStderr({
    required super.session,
    required super.packagePath,
    super.targetPackageName,
  });

  @override
  void warning(String message) {
    stderr.writeln(message);
  }
}
