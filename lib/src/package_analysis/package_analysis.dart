import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

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
    final packageLocation = await checkArgs(argResults!.rest);

    final session = AnalysisContextCollection(includedPaths: [packageLocation])
        .contextFor(packageLocation)
        .currentSession;

    final packageShape = await summarizePackage(
      PackageAnalysisContextWithStderr(session),
      packageLocation,
    );

    final packageJson = packageShape.toJson();

    print(indentedEncoder.convert(packageJson));
  }
}

class LowerBoundConstraintAnalysisCommand extends Command {
  @override
  final name = 'lbcanalysis';
  @override
  final description = 'Performs lower bound analysis.';

  LowerBoundConstraintAnalysisCommand();

  @override
  Future<void> run() async {
    // TODO: perform input validation
    // required arguments:
    // package metadata json path;
    // temp directory path for storing packages during analysis
    // start index
    // end index
    final arguments = argResults!.rest;

    final doc = json.decode(await File(arguments[0]).readAsString());

    for (var packageIndex = int.parse(arguments[2]);
        packageIndex <= int.parse(arguments[3]);
        packageIndex++) {
      final packageDoc = doc['packages'][packageIndex];
      final packageName = packageDoc['name'] as String;

      print('Reviewing package $packageName...');

      final baseFolder = path.canonicalize(arguments[1]);

      final targetPath = path.join(baseFolder, 'target');
      final dependencyFolder = path.join(baseFolder, 'dependencies');

      try {
        await fetchPackageAndDependencies(
          name: packageName,
          version: packageDoc['latest']['version'] as String,
          destination: targetPath,
          wipeTarget: true,
        );
      } on ProcessException catch (exception) {
        // TODO: do not write to stderr here, instead figure out a way to use rootPackageAnalysisContext.warning here - see below (beginning 'can we create this session..')
        stderr.writeln(
            'Failed to download target package  $packageName with error code ${exception.errorCode}: ${exception.message}');
      }

      final dependencies = await getHostedDependencies(targetPath);

      // if there are no dependencies, there is nothing to analyze
      if (dependencies.isEmpty) {
        continue;
      }

      // TODO: can we create this session before downloading the package? we already know the location of the target package.
      // create session for analysing the package being searched for issues
      // (the target package)
      final collection = AnalysisContextCollection(includedPaths: [targetPath]);
      final rootPackageAnalysisContext = PackageAnalysisContextWithStderr(
          collection.contextFor(targetPath).currentSession);

      final dependencySummaries = <String, PackageShape>{};
      final dependencyInstalledVersions = <String, Version>{};

      // iterate over each dependency of the target package and for each one:
      // - determine minimum allowed version
      // - determine installed (current/actual) version
      // - download minimum allowed version
      // - produce a summary of the minimum allowed version
      for (final dependencyEntry in dependencies.entries) {
        final dependencyName = dependencyEntry.key;
        final dependencyVersionConstraint = dependencyEntry.value.version;
        final dependencyDestination =
            path.join(dependencyFolder, '${dependencyName}_pointer');
        final dependencyDoc = (doc['packages'] as List)
            .firstWhere((package) => package['name'] == dependencyName);

        // determine the minimum allowed version of this dependency as allowed
        // by the constraints imposed by the target package
        final allVersionsString = dependencyDoc['versions'] as List<String>;
        final allVersions = allVersionsString.map(Version.parse).toList();
        // allVersions is already sorted by order of increasing version
        final minVersionIndex = findMinAllowedVersion(
          constraint: dependencyVersionConstraint,
          versions: allVersions,
        );
        if (minVersionIndex == null) {
          rootPackageAnalysisContext.warning(
              'Could not determine minimum allowed version for dependency $dependencyName, skipping it.');
          continue;
        }

        // find the installed version of this dependency
        try {
          dependencyInstalledVersions[dependencyName] =
              await getInstalledVersion(
            packageAnalysisContext: rootPackageAnalysisContext,
            dependencyName: dependencyName,
          );
        } on Exception catch (e) {
          rootPackageAnalysisContext.warning(e.toString());
          continue;
        }

        // download minimum allowed version of dependency
        try {
          await fetchUsingDummyPackage(
            name: dependencyName,
            version: minVersionIndex.toString(),
            destination: dependencyDestination,
            wipeTarget: true,
          );
        } on ProcessException catch (exception) {
          rootPackageAnalysisContext.warning(
              'Failed to download dependency $dependencyName of target package $packageName with error code ${exception.errorCode}: ${exception.message}');
        }

        // TODO: can we create this session before downloading the package? we already know the location of the dummy package
        // create session for producing a summary of this dependency
        final collection = AnalysisContextCollection(includedPaths: [
          targetPath,
        ]);
        final dependencyPackageAnalysisContext = PackageAnalysisContextWithStderr(
            collection.contextFor(targetPath).currentSession);

        final realDependencyLocation = await getDependencyDirectory(
          dependencyPackageAnalysisContext,
          dependencyName,
        );

        // produce a summary of the minimum version of this dependency and store it
        dependencySummaries[dependencyName] = await summarizePackage(
          dependencyPackageAnalysisContext,
          realDependencyLocation!,
        );
      }

      final foundIssues = await reportIssues(
        packageAnalysisContext: rootPackageAnalysisContext,
        packageLocation: targetPath,
        rootPackageName: packageName,
        dependencySummaries: dependencySummaries,
        targetDependencies: dependencies,
        dependencyInstalledVersions: dependencyInstalledVersions,
      );

      for (final issue in foundIssues) {
        rootPackageAnalysisContext.warning(
            'symbol ${issue.identifier} could not be found in ${issue.dependencyPackageName} version ${issue.lowestVersion.toString()}');
      }
    }
  }
}

/// Verify that there is only one argument, that it points to a directory, that
/// this directory contains both a `.dart_tool/package_config.json` file and a
/// `pubspec.yaml` file.
Future<String> checkArgs(List<String> paths) async {
  if (paths.length != 1) {
    throw ArgumentError('Only specify exactly one directory for analysis.');
  }

  final packageLocation = path.canonicalize(paths.first);

  if (!await Directory(packageLocation).exists()) {
    throw ArgumentError('Specify a directory for analysis.');
  }

  if (!await File(
          path.join(packageLocation, '.dart_tool', 'package_config.json'))
      .exists()) {
    throw StateError(
        'Run `dart pub get` to fetch dependencies before analysing this package.');
  }

  if (!await File(path.join(packageLocation, 'pubspec.yaml')).exists()) {
    throw StateError('The target directory must contain a package.');
  }

  return packageLocation;
}

// TODO: better name for this class?
@internal
class PackageAnalysisContextWithStderr extends PackageAnalysisContext {
  @override
  late final AnalysisSession analysisSession;

  PackageAnalysisContextWithStderr(AnalysisSession session) {
    analysisSession = session;
  }

  @override
  void warning(String message) {
    stderr.writeln(message);
  }
}
