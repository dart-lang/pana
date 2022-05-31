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
      exitFatal('Please specify exactly one directory for analysis.', 1);
    }

    final packageLocation = paths.first;
    await generateSummary(packageLocation);
  }
}
