// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
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
import 'package:yaml/yaml.dart';

const indentedEncoder = JsonEncoder.withIndent('  ');

class PackageAnalysisContext {
  late final AnalysisSession analysisSession;

  /// Whether the package being analysed uses a dummy.
  late final bool _dummy = _targetPackageName != null;

  /// The name of the singular dependency of this target dummy package, or null
  /// if the package being analysed does not use a dummy.
  late final String? _targetPackageName;

  /// The name of the package being analyzed.
  late final String packageName = _dummy ? _targetPackageName! : pubspec.name;

  /// The path of the package being analyzed, or that of the dummy package, if a
  /// dummy package is used. This path will never be in the pub cache.
  late final String _topLevelPackagePath;

  /// The path of the package being analyzed. If a dummy package is being used,
  /// this path may be in the pub cache.
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

  late final StringSink _warningSink;

  /// Log [message] as a warning that something unexpected happened.
  void warning(String message) {
    _warningSink.writeln(message);
  }

  /// Get the contents of the file at [path] using the `analysisSession.resourceProvider`.
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
    // If the path corresponding to this uri could be resolved,
    // move up one directory (out of `lib/`).
    return path.dirname(uriPath);
  }

  /// Given the context for a package and the name of one of its dependencies,
  /// which may be transitive, return the dependency version which is installed.
  Version findInstalledVersion(String packageName) {
    final lockfilePath = path.join(
      _topLevelPackagePath,
      'pubspec.lock',
    );
    final lockfileDoc = loadYaml(readFile(lockfilePath));
    final versionString =
        lockfileDoc['packages'][packageName]['version'] as String;
    return Version.parse(versionString);
  }

  /// Finds all the typedefs made available by the imports in the library at
  /// [uri] *(as well as those defined in the library itself rather than imported)*
  /// and returns a [Map] from the name of a target [Type] to the names of the
  /// typedefs (the aliases) which point to this [Type], ignoring any function
  /// types and other typedefs for which a target name cannot be resolved.
  Future<Map<String, List<String>>> findTypedefs(Uri uri) async {
    // Attempting to get a resolved library result for a library which is split
    // into parts will fail, so we get a resolved unit first.
    final unitResult = await analysisSession.getResolvedUnit(uriToPath(uri)!);
    if (unitResult is! ResolvedUnitResult) {
      throw AnalysisException(
          'Attempting to get a resolved unit for uri $uri resulted in an invalid result.');
    }
    final library = unitResult.libraryElement;

    final typedefs = <TypeAliasElement>[];
    for (final importedLibrary in library.importedLibraries) {
      // Filter out typedefs where we cannot resolve the target name.
      typedefs.addAll(importedLibrary.exportNamespace.definedNames.values
          .whereType<TypeAliasElement>()
          .where(
              (thisTypedef) => thisTypedef.aliasedType.element2?.name != null));
    }

    // Also consider typedefs defined in the the library itself.
    typedefs.addAll(library.exportNamespace.definedNames.values
        .whereType<TypeAliasElement>()
        .where(
            (thisTypedef) => thisTypedef.aliasedType.element2?.name != null));

    final typedefMap = <String, List<String>>{};
    for (final thisTypedef in typedefs) {
      final targetName = thisTypedef.aliasedType.element2!.name!;
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
    required StringSink warningSink,
    String? targetPackageName,
  }) {
    analysisSession = session;
    _targetPackageName = targetPackageName;
    _topLevelPackagePath = packagePath;
    this.packagePath =
        _dummy ? findPackagePath(targetPackageName!) : packagePath;
    _warningSink = warningSink;
  }
}

/// Download version [version] of the package [name] to the directory
/// [destination] and fetch its dependencies, assuming that this directory does
/// not exist.
///
/// A dummy package will be created at [destination] with a single dependency,
/// pinning the dependency [name] to version [version].
///
/// If [pubHostedUrl] is provided, this url will be used in the pubspec of the
/// dummy package to fetch package [name].
///
/// If [pubCachePath] is provided, the environment variable `PUB_CACHE` is set
/// to its value while fetching dependencies.
Future<void> fetchUsingDummyPackage({
  required String name,
  required String version,
  required String destination,
  String? pubHostedUrl,
  String? pubCachePath,
}) async {
  if (await Directory(destination).exists()) {
    throw StateError(
        'Directory at $destination exists, cannot create dummy package.');
  }

  // Construct pubspec for the dummy package.
  final dummyPubspec = <String, dynamic>{
    'name': 'dummy.package',
    'environment': {
      'sdk': '>=2.13.0 <3.0.0',
    },
    'dependencies': pubHostedUrl == null
        ? {
            name: version,
          }
        : {
            name: {
              'hosted': {
                'name': name,
                'url': pubHostedUrl,
              },
              'version': version,
            }
          },
  };

  // Write pubspec to disk.
  final pubspecFile = await File(path.join(destination, 'pubspec.yaml'))
      .create(recursive: true);
  await pubspecFile.writeAsString(
    json.encode(dummyPubspec),
    flush: true,
  );

  // Fetch dependencies (the only non-transitive dependency is [name]).
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get'],
    workingDirectory: destination,
    environment: pubCachePath == null ? null : {'PUB_CACHE': pubCachePath},
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
List<resource.File> allFilesInFolder(resource.Folder folder) {
  final files = <resource.File>[];
  if (!folder.exists) {
    // There are no files in [folder].
    return files;
  }
  for (final child in folder.getChildren()) {
    if (child is resource.File) {
      files.add(child);
    } else if (child is resource.Folder) {
      files.addAll(allFilesInFolder(child));
    } else {
      throw StateError(
          'Failed to determine subclass of Resource ${child.path}.');
    }
  }
  return files;
}

/// Retrieve the [List<Version>] of available (non-retracted) versions of the
/// package named [packageName], in ascending order of [Version]. [cachePath]
/// can be optionally provided to avoid repetitive requests to the pub api.
/// The returned [List] may be empty.
Future<List<Version>> fetchSortedPackageVersionList({
  required String packageName,
  String? cachePath,
  String? pubHostedUrl,
}) async {
  List<Version> metadataStringToSortedVersions(String metadata) {
    final versionsMetadata = json.decode(metadata)['versions'] as List<dynamic>;
    return versionsMetadata
        .where((versionMetadata) => versionMetadata['retracted'] != true)
        .map((versionMetadata) => versionMetadata['version'] as String)
        .map(Version.parse)
        .sorted((a, b) => a.compareTo(b))
        .toList();
  }

  late final File versionListFile;
  if (cachePath != null) {
    final cachedVersionPath = path.join(cachePath, '$packageName.json');
    versionListFile = File(cachedVersionPath);

    // If package metadata is already cached, just read it from disk.
    if (await versionListFile.exists()) {
      return metadataStringToSortedVersions(
          await versionListFile.readAsString());
    }
  }

  // Otherwise, we need to fetch it from pub.
  final c = http.Client();
  late final http.Response metadataResponse;

  try {
    metadataResponse = await retry(
      () => c.get(Uri.parse(
          '${pubHostedUrl ?? 'https://pub.dev'}/api/packages/$packageName')),
      retryIf: (e) => e is IOException,
    );
  } finally {
    c.close();
  }

  if (metadataResponse.statusCode != HttpStatus.ok) {
    throw HttpException(
        'Failed to download metadata for package $packageName, got http status code ${metadataResponse.statusCode}.');
  }

  // If the response is ok, optionally save the metadata to the cache and return the version list.
  if (cachePath != null) {
    await versionListFile.writeAsString(
      metadataResponse.body,
      flush: true,
    );
  }
  return metadataStringToSortedVersions(metadataResponse.body);
}

/// Returns the package name from a library identifier/uri, or `null` if [uri]
/// isn't of the form `package:*`.
String? packageFromLibraryUri(Uri uri) {
  if (uri.scheme != 'package') {
    return null;
  }
  return uri.pathSegments.firstOrNull;
}

/// Validates existence of [userProvidedPath] if it's not `null`. Otherwise,
/// creates a temporary cache in the system temp directory, to be deleted after
/// analysis terminates.
Future<CacheMetadata> validateCacheOrAutoGenerate(
    String? userProvidedPath) async {
  if (userProvidedPath != null) {
    // If the user has provided a cache path, ensure it exists on disk.
    if (!(await Directory(userProvidedPath).exists())) {
      throw ArgumentError(
          'The directory $userProvidedPath containing package metadata cache could not be found.');
    }
    return CacheMetadata(
      path: userProvidedPath,
      tempDir: null,
    );
  } else {
    // Otherwise, create a temporary cache directory.
    final generatedCacheDir = await Directory(Directory.systemTemp.path)
        .createTemp('lower-bounds-cache');
    return CacheMetadata(
      path: generatedCacheDir.path,
      tempDir: generatedCacheDir,
    );
  }
}

class CacheMetadata {
  /// The path of the cache.
  final String path;

  /// The temporary, auto-generated cache [Directory], or `null` if the cache
  /// path was user-provided.
  final Directory? tempDir;

  CacheMetadata({
    required this.path,
    required this.tempDir,
  });
}
