import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/command_runner.dart';
import 'package:pana/pana.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart' hide Pubspec;

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

    final collection =
        AnalysisContextCollection(includedPaths: [packageLocation]);

    final packageJson = (await summarizePackage(
      _PackageAnalysisContext(collection),
      packageLocation,
    ))
        .toJson();
    const indentedEncoder = JsonEncoder.withIndent('  ');
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

      final targetFolder = path.join(baseFolder, 'target');
      final dependencyFolder = path.join(baseFolder, 'dependencies');

      await fetchPackageAndDependencies(
        name: packageName,
        version: packageDoc['latest']['version'] as String,
        destination: targetFolder,
        wipeTarget: true,
      );

      final allDependencies = Pubspec.parseYaml(
              await File(path.join(targetFolder, 'pubspec.yaml'))
                  .readAsString())
          .dependencies;

      // ensure that this dependency can be found on pub.dev and has version constraints
      // TODO: is there a better way to do this?
      allDependencies.removeWhere((key, value) => value is! HostedDependency);
      final dependencies = Map<String, HostedDependency>.from(allDependencies);

      // if there are no dependencies, there is nothing to analyze
      if (dependencies.isEmpty) {
        continue;
      }

      // TODO: could we just use baseFolder instead of computing the target/dependency paths individually?
      final collection = AnalysisContextCollection(includedPaths: [
        targetFolder,
        ...dependencies.keys.map((name) => path.join(dependencyFolder, name))
      ]);
      final analysisContext = _PackageAnalysisContext(collection);

      final dependencySummaries = <String, PackageShape>{};
      final dependencyInstalledVersions = <String, Version>{};

      // iterate over each one of this package's dependencies and generate a summary
      for (final dependencyEntry in dependencies.entries) {
        final dependencyName = dependencyEntry.key;
        final dependencyVersionConstraint = dependencyEntry.value.version;
        final dependencyDestination =
            path.join(dependencyFolder, dependencyName);

        String? minAllowedVersion;
        if (dependencyVersionConstraint is VersionRange &&
            dependencyVersionConstraint.includeMin) {
          // this first case is very common
          minAllowedVersion = dependencyVersionConstraint.min!.toString();
        } else {
          final dependencyDoc = (doc['packages'] as List<dynamic>)
              .firstWhere((package) => package['name'] == dependencyName);
          final allVersions = (dependencyDoc['versions'] as List<dynamic>)
              .map((version) => version['version'] as String);

          // allVersions is already sorted by order of increasing version
          for (final version in allVersions) {
            if (dependencyVersionConstraint.allows(Version.parse(version))) {
              minAllowedVersion = version;
              break;
            }
          }

          if (minAllowedVersion == null) {
            analysisContext.warning(
                'Could not determine minimum allowed version for dependency $dependencyName, skipping it.');
            continue;
          }
        }

        // find where this dependency was installed for the target package
        final dependencyUri = Uri.parse('package:$dependencyName/');
        final dependencyFilePath = analysisContext
            .contextFor(targetFolder)
            .currentSession
            .uriConverter
            .uriToPath(dependencyUri);
        // could not resolve uri
        if (dependencyFilePath == null) {
          analysisContext.warning(
              'Could not find package directory of dependency $dependencyName, skipping it.');
          continue;
        }

        // fetch the installed version for this dependency
        final dependencyPubspecLocation =
            path.join(path.dirname(dependencyFilePath), 'pubspec.yaml');
        final dependencyPubspec = Pubspec.parseYaml(
            await File(dependencyPubspecLocation).readAsString());
        dependencyInstalledVersions[dependencyName] =
            dependencyPubspec.version!;

        await fetchPackageAndDependencies(
          name: dependencyName,
          version: minAllowedVersion,
          destination: dependencyDestination,
          wipeTarget: true,
        );

        dependencySummaries[dependencyName] = await summarizePackage(
          analysisContext,
          dependencyDestination,
        );
      }

      await reportIssues(
        packageAnalysisContext: analysisContext,
        packageLocation: targetFolder,
        rootPackageName: packageName,
        dependencySummaries: dependencySummaries,
        targetDependencies: dependencies,
        dependencyInstalledVersions: dependencyInstalledVersions,
      );
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

class _PackageAnalysisContext extends PackageAnalysisContext {
  @override
  late final AnalysisContextCollection analysisContextCollection;

  _PackageAnalysisContext(AnalysisContextCollection contextCollection) {
    analysisContextCollection = contextCollection;
  }

  @override
  void warning(String message) {
    stderr.writeln(message);
  }
}
