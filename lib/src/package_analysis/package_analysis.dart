import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/command_runner.dart';
import 'package:pana/src/package_analysis/report_external_usages.dart';
import 'package:pana/src/package_analysis/shapes_ext.dart';

import 'package:path/path.dart' as path;

import 'common.dart';
import 'summary.dart';

Future<void> main(List<String> arguments) async {
  var runner = CommandRunner('package_analysis',
      'A tool for analysing the public API of a dart package.')
    ..addCommand(SummaryCommand())
    ..addCommand(UsagesCommand())
    ..addCommand(LowerBoundAnalysisCommand());
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

    // TODO: maybe make these final
    var collection =
        AnalysisContextCollection(includedPaths: [packageLocation]);

    var packageJson = (await summarizePackage(
      _PackageAnalysisContext(collection),
      packageLocation,
    ))
        .toJson();
    var indentedEncoder = const JsonEncoder.withIndent('  ');
    print(indentedEncoder.convert(packageJson));
  }
}

class UsagesCommand extends Command {
  @override
  final name = 'usages';
  @override
  final description =
      'Displays a summary of usages of symbols defined in an imported package.';

  UsagesCommand();

  @override
  Future<void> run() async {
    final packageLocation = await checkArgs(argResults!.rest);

    final collection =
        AnalysisContextCollection(includedPaths: [packageLocation]);

    final usages = await reportUsages(
      _PackageAnalysisContext(collection),
      packageLocation,
      null,
    );

    print(usages.toString());
  }
}

class LowerBoundAnalysisCommand extends Command {
  @override
  final name = 'lbanalysis';
  @override
  final description = 'Performs lower bound analysis.';

  LowerBoundAnalysisCommand();

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
      final dependencies = packageDoc['latest']['pubspec']['dependencies']
          as Map<String, dynamic>?;

      // if there are no dependencies, there is nothing to analyse
      if (dependencies == null || dependencies.isEmpty) {
        return;
      }

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

      // TODO: maybe there are other strings we want to ignore, other than 'flutter'?
      final dependencyNames =
          dependencies.keys.where((name) => name != 'flutter');

      // TODO: could we just use baseFolder instead of computing the target/dependency paths individually?
      final collection = AnalysisContextCollection(includedPaths: [
        targetFolder,
        ...dependencyNames.map((name) => path.join(dependencyFolder, name))
      ]);
      final analysisContext = _PackageAnalysisContext(collection);

      final dependencyUsages = await reportUsages(
        analysisContext,
        targetFolder,
        packageName,
      );

      for (final dependencyName in [
        ...dependencyUsages.methods.keys,
        ...dependencyUsages.functions.keys,
      ]) {
        if (dependencies[dependencyName] == null ||
            dependencyName == 'flutter') {
          continue;
        }

        final dependencyVersionConstraint =
            dependencies[dependencyName] as String;
        final dependencyDestination =
            path.join(dependencyFolder, dependencyName);

        // only deal with caret syntax (for now)
        // TODO: deal with other kinds of syntax, use package:pub_semver to help
        if (!dependencyVersionConstraint.startsWith('^')) {
          continue;
        }

        await fetchPackageAndDependencies(
          name: dependencyName,
          version: dependencyVersionConstraint.substring(1),
          destination: dependencyDestination,
          wipeTarget: true,
        );

        final package = await summarizePackage(
          analysisContext,
          dependencyDestination,
        );

        final missingFunctions = dependencyUsages.functions[dependencyName]
                ?.difference(package.getFunctions.toSet()) ??
            <String>{};
        if (missingFunctions.isNotEmpty) {
          print(
              '$dependencyName ${dependencyVersionConstraint.substring(1)} is missing top-level functions $missingFunctions');
        }

        final missingMethods = dependencyUsages.methods[dependencyName]
                ?.difference(package.getMethods.toSet()) ??
            <String>{};
        if (missingMethods.isNotEmpty) {
          print(
              '$dependencyName ${dependencyVersionConstraint.substring(1)} is missing class methods $missingMethods');
        }
      }
    }
  }
}

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
