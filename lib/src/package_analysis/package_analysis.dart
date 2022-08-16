import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
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

    // create a unique temporary directory for the target and the dependencies
    final tempDir = await Directory(Directory.systemTemp.path)
        .createTemp('lbcanalysis_temp');

    try {
      final foundIssues = await lowerBoundConstraintAnalysis(
        targetName: targetName,
        tempPath: path.canonicalize(tempDir.path),
        cachePath: cachePath,
      );

      for (final issue in foundIssues) {
        print(
            'Symbol ${issue.kind} ${issue.identifier} with parent ${issue.parentName} is used in $targetName but could not be found in dependency ${issue.dependencyPackageName} version ${issue.lowestVersion}, which is allowed by constraint ${issue.constraint}.');
        for (final reference in issue.references) {
          print(reference.message(''));
        }
      }
    } finally {
      // clean up by deleting the temp directory
      await tempDir.delete(recursive: true);
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
          }
          if (err.isNotEmpty) {
            final stderrLog = File('$logPathPrefix stderr.txt').openWrite();
            err.forEach(stderrLog.add);
          }

          if (exitCode != 0) {
            stderr.writeln(
                'Analysis of package $targetPackageName completed with a non-zero exit code.');
          }
        } catch (e) {
          stderr.writeln(
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
