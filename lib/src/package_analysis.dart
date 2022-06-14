import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/command_runner.dart';

import './package_analysis/common.dart';
import './package_analysis/summary.dart';

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
      throw const PackageAnalysisError(
          'Only specify exactly one directory for analysis.');
    }

    final packageLocation = paths.first;
    await generateSummary(packageLocation);
  }
}

class _PackageAnalysisContext extends PackageAnalysisContext {
  @override
  void error(String message) {
    stderr.writeln(message);
    exit(2);
  }

  @override
  // TODO: implement analysisContextCollection
  AnalysisContextCollection get analysisContextCollection =>
      throw UnimplementedError();
}
