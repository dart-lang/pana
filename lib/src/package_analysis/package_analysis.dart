import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'lower_bound_constraint_analysis.dart';
import 'summary.dart';

Future<void> main(List<String> arguments) async {
  var runner = CommandRunner('package_analysis',
      'A tool for analysing the public API of a dart package.')
    ..addCommand(SummaryCommand())
    ..addCommand(LowerBoundConstraintAnalysisCommand());
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

    print(
        '${DateTime.now().toIso8601String()} Reviewing package $targetName...');

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
