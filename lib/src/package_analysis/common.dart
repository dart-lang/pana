import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:pana/pana.dart';

abstract class PackageAnalysisContext {
  AnalysisContextCollection get analysisContextCollection;

  AnalysisContext contextFor(String path) =>
      analysisContextCollection.contextFor(path);

  /// Log [message] as a warning that something unexpected happened.
  void warning(String message);
}

Future<void> fetchPackageAndDependencies({
  required String name,
  required String version,
  required String destination,
  required bool wipeTarget,
}) async {
  // delete the target directory, if it exists and wipe is enabled
  if (wipeTarget && await Directory(destination).exists()) {
    await Directory(destination).delete(recursive: true);
  }

  // download the package and run `dart pub get`
  await downloadPackage(name, version, destination: destination);
  await Process.run('dart', ['pub', 'get'], workingDirectory: destination);

  return;
}
