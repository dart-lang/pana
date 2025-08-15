import 'dart:io';
import 'package:args/args.dart';
import 'package:pana/src/license_detection/license_detector.dart';

/// A command line program to use access the license detector.
///
/// The program take two parameters `--path` and `--threshold`.
/// If threshold is not provided it defaults to `0.9`.
void main(List<String> arguments) async {
  final parser = ArgParser();
  parser.addOption('path');
  parser.addOption('threshold');
  var argResults = parser.parse(arguments);

  var threshold = argResults['threshold'] ?? 0.9;
  var path = argResults['path'];

  if (path == null) {
    print('Path not specified');
    return;
  }

  final file = File(path as String);
  var content = await file.readAsString();

  final detectionResult = await detectLicense(content, threshold as double);

  if (detectionResult.matches.isEmpty) {
    print('No license found in the given file');
  } else {
    var i = 1;
    print(
      'unclaimedTokenPercentage:  ${detectionResult.unclaimedTokenPercentage}',
    );
    print(
      'longestUnclaimedTokenCount:  ${detectionResult.longestUnclaimedTokenCount}',
    );
    for (var match in detectionResult.matches) {
      print('\nDetection result $i: ');
      print('Spdx identifier: ${match.identifier}');
      print('Confidence: ${match.confidence}');
      print('Start Offset: ${match.start} End offset: ${match.end}');
    }
  }
}
