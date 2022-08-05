import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
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
  final description = 'Performs lower bound analysis.';
  @override
  final usage = '''Required positional arguments:
  1) path to a json file with package metadata
  2) index of the first package to be analyzed
  3) index of the last package to be analyzed''';

  LowerBoundConstraintAnalysisCommand();

  @override
  Future<void> run() async {
    final arguments = argResults!.rest;
    if (arguments.length != 3) {
      throw ArgumentError(
          'This command accepts exactly 3 positional arguments.');
    }

    final packageMetadataPath = arguments[0];
    final startIndex = int.tryParse(arguments[1]);
    final endIndex = int.tryParse(arguments[2]);
    if (!await File(packageMetadataPath).exists()) {
      throw ArgumentError(
          'The file containing package metadata could not be found.');
    }
    if (startIndex == null || endIndex == null) {
      throw ArgumentError('The start/end index could not be parsed.');
    }

    final doc =
        json.decode(await File(packageMetadataPath).readAsString())['packages']
            as List;

    for (var targetIndex = startIndex; targetIndex <= endIndex; targetIndex++) {
      final targetDoc = doc[targetIndex]['metadata'];
      final targetName = targetDoc['name'] as String;

      print(
          '${DateTime.now().toIso8601String()} Reviewing package $targetIndex $targetName...');

      // create a unique temporary directory for the target and the dependencies
      final tempDir = await Directory(Directory.systemTemp.path)
          .createTemp('lbcanalysis_temp');
      final baseFolder = path.canonicalize(tempDir.path);

      final dummyPath = path.join(baseFolder, 'target');
      final dependencyFolder = path.join(baseFolder, 'dependencies');

      try {
        await fetchUsingDummyPackage(
          name: targetName,
          version: targetDoc['latest']['version'] as String,
          destination: dummyPath,
          wipeTarget: true,
        );
      } on ProcessException catch (exception) {
        // TODO: do not write to stderr here, instead figure out a way to use rootPackageAnalysisContext.warning here - see below (beginning 'can we create this session..')
        stderr.writeln(
            'Skipping target package $targetName, failed to download it with error code ${exception.errorCode}: ${exception.message}');
        continue;
      }

      // TODO: can we create this session before downloading the package? we already know the location of the target package.
      // create session for analysing the package being searched for issues
      // (the target package)
      final collection = AnalysisContextCollection(includedPaths: [dummyPath]);
      final dummyPackageAnalysisContext = PackageAnalysisContextWithStderr(
        session: collection.contextFor(dummyPath).currentSession,
        packagePath: dummyPath,
        targetPackageName: targetName,
      );

      // if there are no dependencies, there is nothing to analyze
      if (dummyPackageAnalysisContext.dependencies.isEmpty) {
        continue;
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
            path.join(dependencyFolder, '${dependencyName}_pointer');
        final dependencyDoc = doc.firstWhereOrNull((package) => package['metadata']['name'] as String == dependencyName);

        // if dependency could not be found in the doc, skip it
        if (dependencyDoc == null) {
          continue;
        }

        // determine the minimum allowed version of this dependency as allowed
        // by the constraints imposed by the target package
        final allVersionsString = (dependencyDoc['metadata']['versions'] as List)
            .map((element) => element['version'] as String).toList();
        final allVersions = allVersionsString.map(Version.parse).toList();
        final minVersion = findMinAllowedVersion(
          constraint: dependencyVersionConstraint,
          versions: allVersions,
        );
        if (minVersion == null) {
          dummyPackageAnalysisContext.warning(
              'Skipping dependency $dependencyName, could not determine minimum allowed version.');
          continue;
        }

        // download minimum allowed version of dependency
        try {
          await fetchUsingDummyPackage(
            name: dependencyName,
            version: minVersion.toString(),
            destination: dependencyDestination,
            wipeTarget: true,
          );
        } on ProcessException catch (exception) {
          dummyPackageAnalysisContext.warning(
              'Skipping dependency $dependencyName of target package $targetName, failed to download it with error code ${exception.errorCode}: ${exception.message}');
          continue;
        }

        // TODO: can we create this session before downloading the package? we already know the location of the dummy package
        // create session for producing a summary of this dependency
        final collection = AnalysisContextCollection(includedPaths: [
          dependencyDestination,
        ]);
        final dependencyPackageAnalysisContext =
            PackageAnalysisContextWithStderr(
          session: collection.contextFor(dependencyDestination).currentSession,
          packagePath: dependencyDestination,
        );

        // produce a summary of the minimum version of this dependency and store it
        dependencySummaries[dependencyName] = await summarizePackage(
          context: dependencyPackageAnalysisContext,
          packagePath: dependencyPackageAnalysisContext.findPackagePath(dependencyName),
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
