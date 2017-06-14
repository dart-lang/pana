// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/file_system.dart' hide File;
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/package_map_resolver.dart';
import 'package:analyzer/source/pub_package_map_provider.dart';
import 'package:analyzer/src/dart/sdk/sdk.dart' show FolderBasedDartSdk;
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:cli_util/cli_util.dart' as cli;
import 'package:path/path.dart' as p;

import 'utils.dart';

class LibraryScanner {
  final String _package;
  final String _projectPath;
  final UriResolver _packageResolver;
  final AnalysisContext _context;
  final Map<String, List<String>> _cachedLibs = {};

  LibraryScanner._(
      this._package, this._projectPath, this._packageResolver, this._context);

  factory LibraryScanner(String package, String projectPath, bool useFlutter) {
    // TODO: fail more clearly if this...fails
    var sdkPath = cli.getSdkDir().path;

    var resourceProvider = PhysicalResourceProvider.INSTANCE;
    DartSdk sdk = new FolderBasedDartSdk(
        resourceProvider, resourceProvider.getFolder(sdkPath));

    var dotPackagesPath = p.join(projectPath, '.packages');
    if (!FileSystemEntity.isFileSync(dotPackagesPath)) {
      throw new StateError('A package configuration file was not found at the '
          'expectetd location.\n$dotPackagesPath');
    }

    RunPubList runPubList;
    if (useFlutter) {
      runPubList = _flutterPubList;
    }

    var pubPackageMapProvider = new PubPackageMapProvider(
        PhysicalResourceProvider.INSTANCE, sdk, runPubList);
    var packageMapInfo = pubPackageMapProvider.computePackageMap(
        PhysicalResourceProvider.INSTANCE.getResource(projectPath));
    var packageMap = packageMapInfo.packageMap;
    if (packageMap == null) {
      throw new StateError('An error occurred getting the package map '
          'for the file at `$dotPackagesPath`.');
    }
    UriResolver packageResolver = new PackageMapUriResolver(
        PhysicalResourceProvider.INSTANCE, packageMap);

    var resolvers = [
      new DartUriResolver(sdk),
      new ResourceUriResolver(PhysicalResourceProvider.INSTANCE),
      packageResolver,
    ];

    AnalysisEngine.instance.processRequiredPlugins();

    var options = new AnalysisOptionsImpl()..analyzeFunctionBodies = false;

    AnalysisContext context = AnalysisEngine.instance.createAnalysisContext()
      ..analysisOptions = options
      ..sourceFactory = new SourceFactory(resolvers);
    return new LibraryScanner._(package, projectPath, packageResolver, context);
  }

  Future<Map<String, List<String>>> scanDirectLibs() => _scanPackage();

  Future<Map<String, List<String>>> scanTransitiveLibs() async {
    Map<String, List<String>> results = new SplayTreeMap();
    Map<String, List<String>> direct = await _scanPackage();
    for (String key in direct.keys) {
      Set<String> processed = new Set();
      Set<String> todo = new Set.from(direct[key]);
      while (todo.isNotEmpty) {
        String lib = todo.first;
        todo.remove(lib);
        if (processed.contains(lib)) continue;
        processed.add(lib);
        if (lib.startsWith('dart:')) {
          // nothing to do
        } else if (_cachedLibs.containsKey(lib)) {
          todo.addAll(_cachedLibs[lib]);
        } else if (lib.startsWith('package:')) {
          todo.addAll(await _scanUri(lib));
        }
      }

      results[key] = processed.toList()..sort();
    }
    return results;
  }

  /// [AnalysisEngine] caches analyzed fragments, and we need to clear those
  /// after we have analyzed a package.
  void clearCaches() {
    AnalysisEngine.instance.clearCaches();
  }

  Future<List<String>> _scanUri(String libUri) async {
    Uri uri = Uri.parse(libUri);
    String package = uri.pathSegments.first;

    var source = _packageResolver.resolveAbsolute(uri);
    if (source == null) {
      throw "Could not resolve package URI for $uri";
    }

    String fullPath = source.fullName;
    String relativePath =
        p.join('lib', libUri.substring(libUri.indexOf('/') + 1));
    if (fullPath.endsWith('/$relativePath')) {
      String packageDir =
          fullPath.substring(0, fullPath.length - relativePath.length - 1);
      List<String> libs = _parseLibs(package, packageDir, relativePath);
      _cachedLibs[libUri] = libs;
      return libs;
    } else {
      return [];
    }
  }

  Future<Map<String, List<String>>> _scanPackage() async {
    Map<String, List<String>> results = new SplayTreeMap();
    List<String> dartFiles = await listFiles(_projectPath, endsWith: '.dart');
    List<String> mainFiles = dartFiles.where((path) {
      if (p.isWithin('bin', path)) {
        return true;
      }

      // Include all Dart files in lib – except for implementation files.
      if (p.isWithin('lib', path) && !p.isWithin('lib/src', path)) {
        return true;
      }

      return false;
    }).toList();
    for (String relativePath in mainFiles) {
      String uri = toPackageUri(_package, relativePath);
      if (!_cachedLibs.containsKey(uri)) {
        _cachedLibs[uri] = _parseLibs(_package, _projectPath, relativePath);
      }
      results[uri] = _cachedLibs[uri];
    }
    return results;
  }

  List<String> _parseLibs(
      String package, String packageDir, String relativePath) {
    String fullPath = p.join(packageDir, relativePath);
    LibraryElement lib = _getLibraryElement(fullPath);
    if (lib == null) return [];
    Set<String> refs = new SplayTreeSet();
    lib.importedLibraries.forEach((le) {
      refs.add(_normalizeLibRef(le.librarySource.uri, package, packageDir));
    });
    lib.exportedLibraries.forEach((le) {
      refs.add(_normalizeLibRef(le.librarySource.uri, package, packageDir));
    });
    refs.remove('dart:core');
    return refs.toList();
  }

  LibraryElement _getLibraryElement(String path) {
    Source source = new FileBasedSource(new JavaFile(path));
    if (_context.computeKindOf(source) == SourceKind.LIBRARY) {
      return _context.computeLibraryElement(source);
    }
    return null;
  }
}

String _normalizeLibRef(Uri uri, String package, String packageDir) {
  if (uri.isScheme('file')) {
    String relativePath = p.relative(p.fromUri(uri), from: packageDir);
    return toPackageUri(package, relativePath);
  } else if (uri.isScheme('package') || uri.isScheme('dart')) {
    return uri.toString();
  }

  throw "not supported - $uri";
}

ProcessResult _flutterPubList(Folder folder) {
  var result =
      Process.runSync('flutter', ['packages', 'pub', 'list-package-dirs']);

  if (result.exitCode == 0 &&
      (result.stdout as String).contains('without superuser privileges')) {
    // So flutter's wrapper around pub yells about superuser
    // ... which only comes up when running via docker
    // SO...we need to strip this crazy out.

    var lines = LineSplitter.split(result.stdout).toList();

    while (lines.isNotEmpty && !lines.first.startsWith("{")) {
      lines.removeAt(0);
    }

    return new ProcessResult(
        result.pid, result.exitCode, lines.join('\n'), result.stderr);
  }

  return result;
}
