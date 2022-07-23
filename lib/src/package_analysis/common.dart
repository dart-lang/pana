import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/file_system/file_system.dart' as resource;
import 'package:pana/pana.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart' hide Pubspec;

const indentedEncoder = JsonEncoder.withIndent('  ');

abstract class PackageAnalysisContext {
  AnalysisSession get analysisSession;

  /// The name of the package being analyzed.
  late final String packageName = pubspec.name;

  /// The absolute path of the package being analyzed.
  final String packagePath;

  /// The pubspec of the package being analyzed.
  late final Pubspec pubspec =
      Pubspec.parseYaml(readFile(path.join(packagePath, 'pubspec.yaml')));

  /// A [Map] storing metadata about the hosted dependencies of the package
  /// being analyzed.
  late final Map<String, HostedDependency> dependencies = Map.fromEntries(
      pubspec
          .dependencies.entries
          .where((dependency) => dependency.value is HostedDependency)
          .map(
              (entry) => MapEntry(entry.key, entry.value as HostedDependency)));

  /// Log [message] as a warning that something unexpected happened.
  void warning(String message);

  /// Get the contents of the file at [path] using the `analysisSession.resourceProvider`
  String readFile(String path) =>
      analysisSession.resourceProvider.getFile(path).readAsStringSync();

  /// Return a `File` that corresponds to the given absolute and normalized [path].
  /// A file may or may not exist at this location.
  resource.File file(String path) =>
      analysisSession.resourceProvider.getFile(path);

  /// Return a `Folder` that corresponds to the given absolute and normalized [path].
  /// A folder may or may not exist at this location.
  resource.Folder folder(String path) =>
      analysisSession.resourceProvider.getFolder(path);

  PackageAnalysisContext({
    required this.packagePath,
  });

  /// Return the absolute path of the file to which the absolute [uri] resolves,
  /// or `null` if the [uri] cannot be resolved in this context.
  ///
  /// Examples of acceptable [uri]s:
  /// * 'package:my_library/'
  /// * 'package:my_library/my_library.dart'
  /// * [uri]s using the the file URI scheme, beginning with 'file:///'
  String? uriToPath(Uri uri) => analysisSession.uriConverter.uriToPath(uri);
}

// TODO: consider deleting unused function
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
Future<void> fetchUsingDummyPackage({
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
    'dependencies': {
      name: version,
    },
  };

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

/// Given the context for a package and the name of one of its dependencies,
/// return the path of the dependency, or null if it cannot be resolved.
/// Ensure that the dependencies of the target package are fetched.
String? getDependencyDirectory(
  PackageAnalysisContext packageAnalysisContext,
  String dependencyName,
) {
  final dependencyUri = Uri.parse('package:$dependencyName/');
  final dependencyFilePath = packageAnalysisContext.uriToPath(dependencyUri);
  // if the path corresponding to this uri could be resolved,
  // move up one directory to move out of lib/
  return dependencyFilePath == null ? null : path.dirname(dependencyFilePath);
}

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
  String targetPackageDir,
) async {
  // fetch a Map of all dependencies from the target package folder
  final allDependencies = Pubspec.parseYaml(
          await File(path.join(targetPackageDir, 'pubspec.yaml'))
              .readAsString())
      .dependencies;

  // ensure that these dependencies can be found on pub.dev and has version constraints
  allDependencies.removeWhere((key, value) => value is! HostedDependency);
  return Map<String, HostedDependency>.from(allDependencies);
}

/// Given the context for a package and the name of one of its dependencies,
/// which may be transitive, return the dependency version which is installed.
Version getInstalledVersion({
  required PackageAnalysisContext context,
  required String dependencyName,
}) {
  final dependencyPubspecLocation = path.join(
    getDependencyDirectory(context, dependencyName)!,
    'pubspec.yaml',
  );
  final dependencyPubspec =
      Pubspec.parseYaml(context.readFile(dependencyPubspecLocation));
  return dependencyPubspec.version!;
}

/// Given a version constraint and a list of versions
/// **from a sorted list of [Version]s in increasing order**, return the the
/// minimum [Version] allowed by the constraint, or null if no version in the
/// list is allowed by the constraint.
Version? findMinAllowedVersion({
  required VersionConstraint constraint,
  required List<Version> versions,
}) {
  // this first case is common
  if (constraint is VersionRange &&
      constraint.includeMin &&
      versions.contains(constraint.min!)) {
    return constraint.min!;
  }

  for (final version in versions) {
    if (constraint.allows(version)) {
      return version;
    }
  }
  return null;
}
