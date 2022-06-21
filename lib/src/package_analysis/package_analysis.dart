import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/command_runner.dart';

import 'package:path/path.dart' as path;

import 'common.dart';
import 'summary.dart';

Future<void> main(List<String> arguments) async {
  var runner = CommandRunner('package_analysis',
      'A tool for analysing the public API of a dart package.')
    ..addCommand(SummaryCommand());
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
    final paths = argResults!.rest;

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

    var collection =
        AnalysisContextCollection(includedPaths: [packageLocation]);

    var packageJson = (await summarizePackage(
            _PackageAnalysisContext(collection), packageLocation))
        .toJson();
    var indentedEncoder = const JsonEncoder.withIndent('  ');
    print(indentedEncoder.convert(packageJson));
  }
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
