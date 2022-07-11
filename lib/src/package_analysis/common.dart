import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/file_system/file_system.dart' as resource;
import 'package:pana/pana.dart';
import 'package:path/path.dart' as path;
import 'package:pubspec_parse/pubspec_parse.dart' hide Pubspec;

const indentedEncoder = JsonEncoder.withIndent('  ');

abstract class PackageAnalysisSession {
  AnalysisSession get analysisSession;

  /// Log [message] as a warning that something unexpected happened.
  void warning(String message);
}

/// Download version [version] of the package [name] to the directory
/// [destination] and fetch its dependencies, optionally deleting the contents
/// of [destination] first if [wipeTarget] is set to true.
///
/// The package will be downloaded using `downloadPackage` from
/// `package:pana/src/download_utils.dart`.
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

  // download the package and fetch dependencies
  await downloadPackage(name, version, destination: destination);
  await fetchDependencies(destination);
  return;
}

/// Download version [version] of the package [name] to the directory
/// [destination] and fetch its dependencies, optionally deleting the contents
/// of [destination] first if [wipeTarget] is set to true.
///
/// A pointer package will be created at [destination] with a single dependency,
/// pinning the dependency [name] to version [version].
Future<void> fetchPackageWithPointer({
  required String name,
  required String version,
  required String destination,
  required bool wipeTarget,
}) async {
  // delete the target directory, if it exists and wipe is enabled
  if (wipeTarget && await Directory(destination).exists()) {
    await Directory(destination).delete(recursive: true);
  }

  // construct pubspec for the pointer package
  final pointerPubspec = <String, dynamic>{
    'name': 'dummy_package',
    'environment': {
      'sdk': '>=2.12.0 <3.0.0',
    },
    'dependencies': {},
  };
  pointerPubspec['dependencies'][name] = version;

  // if pubspec.yaml exists, delete it and create an empty file
  final pubspecFile = File(path.join(destination, 'pubspec.yaml'));
  if (await pubspecFile.exists()) {
    await pubspecFile.delete();
  }
  await pubspecFile.create(recursive: true);

  // write pubspec to disk
  await pubspecFile.writeAsString(json.encode(pointerPubspec));

  // fetch dependencies (the only non-transitive dependency is [name])
  await fetchDependencies(destination);
}

/// Fetches dependencies in [destination].
Future<void> fetchDependencies(String destination) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get'],
    workingDirectory: destination,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      ['pub', 'get'],
      result.stderr.toString(),
      result.exitCode,
    );
  }
}

/// Given the location of a package and the name of one of its dependencies,
/// return the path of the dependency, or null if it cannot be resolved.
/// Ensure that the dependencies of the target package are fetched.
Future<String?> getDependencyDirectory(
  PackageAnalysisSession packageAnalysisSession,
  String packageLocation,
  String dependencyName,
) async {
  final dependencyUri = Uri.parse('package:$dependencyName/');
  final dependencyFilePath = packageAnalysisSession.analysisSession.uriConverter
      .uriToPath(dependencyUri);
  return dependencyFilePath == null ? null : path.dirname(dependencyFilePath);
}

// TODO: test this feature by creating a summary of a package with a deeply nested library, one public, one private
/// Recursively fetch all the files in the given folder
List<resource.File> getAllFiles(resource.Folder folder) {
  final files = <resource.File>[];
  for (final child in folder.getChildren()) {
    if (child is resource.File) {
      files.add(child);
    } else if (child is resource.Folder) {
      files.addAll(getAllFiles(child));
    } else {
      throw StateError(
          'Failed to determine subclass of Resource ${child.path}.');
    }
  }
  return files;
}

/// Fetch all the hosted dependencies used by a package at a given location
Future<Map<String, HostedDependency>> getHostedDependencies(
    String targetPackageDir) async {
  // fetch a Map of all dependencies from the target package folder
  final allDependencies = Pubspec.parseYaml(
          await File(path.join(targetPackageDir, 'pubspec.yaml'))
              .readAsString())
      .dependencies;

  // ensure that these dependencies can be found on pub.dev and has version constraints
  allDependencies.removeWhere((key, value) => value is! HostedDependency);
  return Map<String, HostedDependency>.from(allDependencies);
}
