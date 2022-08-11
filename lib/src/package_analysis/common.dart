import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:analyzer/file_system/file_system.dart' as resource;
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:pana/pana.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart' hide Pubspec;
import 'package:retry/retry.dart';

const indentedEncoder = JsonEncoder.withIndent('  ');

abstract class PackageAnalysisContext {
  late final AnalysisSession analysisSession;

  /// Shortcut for `_targetPackageName != null`.
  late final bool _dummy = _targetPackageName != null;

  /// The name of the singular dependency of this target dummy package, or null
  /// if the package being analysed does not use a dummy.
  late final String? _targetPackageName;

  /// The name of the package being analyzed.
  late final String packageName = _dummy ? _targetPackageName! : pubspec.name;

  /// The absolute path of the package being analyzed.
  late final String packagePath;

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

  /// Return the absolute path of the file to which the absolute [uri] resolves,
  /// or `null` if the [uri] cannot be resolved in this context.
  ///
  /// Examples of acceptable [uri]s:
  /// * 'package:my_library/'
  /// * 'package:my_library/my_library.dart'
  /// * [uri]s using the the file URI scheme, beginning with 'file:///'
  String? uriToPath(Uri uri) => analysisSession.uriConverter.uriToPath(uri);

  /// Given the name of a package within this context (commonly a direct or
  /// transitive dependency of the target package), return the path of this
  /// package - the path to which `'package:$packageName/'` resolves.
  /// Ensure that the dependencies of the target package are fetched with `pub get`.
  String findPackagePath(String packageName) {
    final uri = Uri.parse('package:$packageName/');
    final uriPath = uriToPath(uri);
    if (uriPath == null) {
      throw StateError(
          'The path to $packageName could not be resolved in the current context.');
    }
    // if the path corresponding to this uri could be resolved,
    // move up one directory to move out of lib/
    return path.dirname(uriPath);
  }

  /// Given the context for a package and the name of one of its dependencies,
  /// which may be transitive, return the dependency version which is installed.
  Version findInstalledVersion(String packageName) {
    final packagePubspecPath = path.join(
      findPackagePath(packageName),
      'pubspec.yaml',
    );
    return Pubspec.parseYaml(readFile(packagePubspecPath)).version!;
  }

  /// Finds all the typedefs made available by the imports in the library at
  /// [uri] *(as well as those defined in the library itself rather than imported)*
  /// and returns a [Map] from the name of a target [Type] to the names of the
  /// typedefs (the aliases) which point to this [Type], ignoring any function
  /// types and other typedefs for which a target name cannot be resolved.
  Future<Map<String, List<String>>> findTypedefs(Uri uri) async {
    // attempting to get a resolved library result for a library split into
    // parts will fail, so we get a resolved unit first
    final unitResult = await analysisSession.getResolvedUnit(uriToPath(uri)!);
    if (unitResult is! ResolvedUnitResult) {
      throw AnalysisException(
          'Attempting to get a resolved unit for uri $uri resulted in an invalid result.');
    }
    final library = unitResult.libraryElement;

    final typedefs = <TypeAliasElement>[];
    for (final importedLibrary in library.importedLibraries) {
      // filter out typedefs where we cannot resolve the target name
      typedefs.addAll(importedLibrary.exportNamespace.definedNames.values
          .whereType<TypeAliasElement>()
          .where(
              (thisTypedef) => thisTypedef.aliasedType.element?.name != null));
    }

    // also consider typedefs defined in the the library itself
    typedefs.addAll(library.exportNamespace.definedNames.values
        .whereType<TypeAliasElement>()
        .where((thisTypedef) => thisTypedef.aliasedType.element?.name != null));

    final typedefMap = <String, List<String>>{};
    for (final thisTypedef in typedefs) {
      final targetName = thisTypedef.aliasedType.element!.name!;
      if (!typedefMap.keys.contains(targetName)) {
        typedefMap[targetName] = <String>[];
      }
      typedefMap[targetName]!.add(thisTypedef.name);
    }

    return typedefMap;
  }

  PackageAnalysisContext({
    required AnalysisSession session,
    required String packagePath,
    String? targetPackageName,
  }) {
    analysisSession = session;
    _targetPackageName = targetPackageName;
    this.packagePath =
        _dummy ? findPackagePath(targetPackageName!) : packagePath;
  }
}

/// Download version [version] of the package [name] to the directory
/// [destination] and fetch its dependencies, optionally deleting the contents
/// of [destination] first if [wipeTarget] is set to true.
///
/// A dummy package will be created at [destination] with a single dependency,
/// pinning the dependency [name] to version [version].
Future<void> fetchUsingDummyPackage({
  required String name,
  required Version version,
  required String destination,
  required bool wipeTarget,
}) async {
  // delete the target directory, if it exists and wipe is enabled
  if (wipeTarget && await Directory(destination).exists()) {
    await Directory(destination).delete(recursive: true);
  }

  // construct pubspec for the dummy package
  final dummyPubspec = <String, dynamic>{
    'name': 'dummy.package',
    'environment': {
      'sdk': '>=2.13.0 <3.0.0',
    },
    'dependencies': {
      name: version.toString(),
    },
  };

  // if pubspec.yaml exists, delete it and create an empty file
  final pubspecFile = File(path.join(destination, 'pubspec.yaml'));
  if (await pubspecFile.exists()) {
    await pubspecFile.delete();
  }
  await pubspecFile.create(recursive: true);

  // write pubspec to disk
  await pubspecFile.writeAsString(json.encode(dummyPubspec));

  // fetch dependencies (the only non-transitive dependency is [name])
  await fetchDependencies(destination);
}

/// Fetches dependencies at the physical path [destination].
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

/// Recursively fetch all the files in the given folder, which may not exist.
List<resource.File> getAllFiles(resource.Folder folder) {
  final files = <resource.File>[];
  if (!folder.exists) {
    // there are no files here
    return files;
  }
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

/// Given the path to the directory containing cached available package version
/// [List<String>]s, retrieve the [List<Version>] of available versions of the
/// package [packageName] in ascending order of [Version], either by using the
/// cache or by sending a request to `https://pub.dev/api/packages/$packageName`
/// (in this case the response is also saved in the cache).
Future<List<Version>> fetchSortedPackageVersionList({
  required String packageName,
  required String cachePath,
}) async {
  List<Version> metadataStringToSortedVersions(String metadata) {
    final versionsMetadata = json.decode(metadata)['versions'] as List<dynamic>;
    return versionsMetadata
        .map((versionMetadata) => versionMetadata['version'] as String)
        .map(Version.parse)
        .sorted((a, b) => a.compareTo(b))
        .toList();
  }

  final cachedVersionPath = path.join(cachePath, '$packageName.json');
  final versionListFile = File(cachedVersionPath);

  // if the version list is already cached, just read it from disk
  if (await versionListFile.exists()) {
    return metadataStringToSortedVersions(await versionListFile.readAsString());
  }

  // otherwise, we need to fetch it from pub
  final c = http.Client();
  late final http.Response metadataResponse;

  try {
    metadataResponse = await retry(
      () => c.get(Uri.parse('https://pub.dev/api/packages/$packageName')),
      retryIf: (e) => e is IOException,
    );
  } finally {
    c.close();
  }

  if (metadataResponse.statusCode != HttpStatus.ok) {
    throw HttpException(
        'Failed to download metadata for package $packageName.');
  }

  // if the response is ok, save the metadata to the cache and return the version list
  await versionListFile.writeAsString(metadataResponse.body);
  return metadataStringToSortedVersions(metadataResponse.body);
}
