import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
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

    final session = AnalysisContextCollection(includedPaths: [packageLocation])
        .contextFor(packageLocation)
        .currentSession;

    final packageShape = await summarizePackage(
      _PackageAnalysisSession(session),
      packageLocation,
    );

    final packageJson = packageShape.toJson();

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
    // Given the location of a package and one of its dependencies, return the
    // dependency version which is installed.
    Future<Version> getInstalledVersion({
      required PackageAnalysisSession packageAnalysisSession,
      required String packageLocation,
      required String dependencyName,
    }) async {
      // find where this dependency was installed for the target package
      final dependencyUri = Uri.parse('package:$dependencyName/');
      final dependencyFilePath = packageAnalysisSession
          .analysisSession.uriConverter
          .uriToPath(dependencyUri);
      // could not resolve uri
      if (dependencyFilePath == null) {
        throw Exception(
            'Could not find package directory of dependency $dependencyName.');
      }

      // fetch the installed version for this dependency
      final dependencyPubspecLocation =
          path.join(path.dirname(dependencyFilePath), 'pubspec.yaml');
      final dependencyPubspec = Pubspec.parseYaml(
          await File(dependencyPubspecLocation).readAsString());
      return dependencyPubspec.version!;
    }

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

      // if (packageName == 'flutter_login_facebook' || packageName == 'amplify_flutter') {
      //   continue;
      // }

      final baseFolder = path.canonicalize(arguments[1]);

      final targetFolder = path.join(baseFolder, 'target');
      final dependencyFolder = path.join(baseFolder, 'dependencies');

      try {
        await fetchPackageAndDependencies(
          name: packageName,
          version: packageDoc['latest']['version'] as String,
          destination: targetFolder,
          wipeTarget: true,
        );
      } on ProcessException catch (exception) {
        // TODO: do not write to stderr here, instead figure out a way to use rootPackageAnalysisSession.warning here - see below (beginning 'can we create this session..')
        stderr.writeln(
            'Failed to download target package  $packageName with error code ${exception.errorCode}: ${exception.message}');
      }

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

      // TODO: can we create this session before downloading the package? we already know the location of the target package.
      // create session for analysing the package being searched for issues
      // (the target package)
      final collection = AnalysisContextCollection(includedPaths: [
        targetFolder,
      ]);
      final rootPackageAnalysisSession = _PackageAnalysisSession(
          collection.contextFor(targetFolder).currentSession);

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

        // determine the minimum allowed version of this dependency as allowed
        // by the constraints imposed by the target package
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
            rootPackageAnalysisSession.warning(
                'Could not determine minimum allowed version for dependency $dependencyName, skipping it.');
            continue;
          }
        }

        // find the installed version of this dependency
        try {
          dependencyInstalledVersions[dependencyName] =
              await getInstalledVersion(
            packageAnalysisSession: rootPackageAnalysisSession,
            packageLocation: targetFolder,
            dependencyName: dependencyName,
          );
        } on Exception catch (e) {
          rootPackageAnalysisSession.warning(e.toString());
          continue;
        }

        // download minimum allowed version of dependency
        try {
          await fetchPackageWithPointer(
            name: dependencyName,
            version: minAllowedVersion,
            destination: dependencyDestination,
            wipeTarget: true,
          );
        } on ProcessException catch (exception) {
          rootPackageAnalysisSession.warning(
              'Failed to download dependency $dependencyName of target package $packageName with error code ${exception.errorCode}: ${exception.message}');
        }

        // TODO: can we create this session before downloading the package? we already know the location of the dummy package
        // create session for producing a summary of this dependency
        final collection = AnalysisContextCollection(includedPaths: [
          targetFolder,
        ]);
        final dependencyPackageAnalysisSession = _PackageAnalysisSession(
            collection.contextFor(targetFolder).currentSession);

        final realDependencyLocation = await getDependencyDirectory(
          dependencyPackageAnalysisSession,
          dependencyDestination,
          dependencyName,
        );

        // produce a summary of the minimum version of this dependency and store it
        dependencySummaries[dependencyName] = await summarizePackage(
          dependencyPackageAnalysisSession,
          realDependencyLocation!,
        );
      }

      var test = await reportIssues(
        packageAnalysisSession: rootPackageAnalysisSession,
        packageLocation: targetFolder,
        rootPackageName: packageName,
        dependencySummaries: dependencySummaries,
        targetDependencies: dependencies,
        dependencyInstalledVersions: dependencyInstalledVersions,
      );
      for (final i in test) {
        print(
            'symbol ${i.identifier} could not be found in ${i.dependencyPackageName} version ${i.lowestVersion.toString()}');
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

class _PackageAnalysisSession extends PackageAnalysisSession {
  @override
  late final AnalysisSession analysisSession;

  _PackageAnalysisSession(AnalysisSession session) {
    analysisSession = session;
  }

  @override
  void warning(String message) {
    stderr.writeln(message);
  }
}
