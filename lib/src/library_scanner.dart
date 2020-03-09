// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

import 'logging.dart';
import 'utils.dart';

class LibraryOverride {
  final String uri;
  final String dependency;
  final String overrideTo;

  LibraryOverride(this.uri, this.dependency, this.overrideTo);
  LibraryOverride.webSafeIO(this.uri)
      : dependency = 'dart:io',
        overrideTo = 'dart-pana:web_safe_io';
}

class LibraryScanner {
  final String packageName;
  final String _packagePath;
  final AnalysisSession _session;
  final List<LibraryOverride> _overrides;
  final _cachedLibs = HashMap<String, List<String>>();
  final _cachedTransitiveLibs = HashMap<String, List<String>>();

  LibraryScanner._(
      this.packageName, this._packagePath, this._session, this._overrides);

  factory LibraryScanner(
      String dartSdkPath, String packageName, String packagePath,
      {List<LibraryOverride> overrides}) {
    var contextLocator = ContextLocator();
    var roots = contextLocator.locateRoots(includedPaths: [packagePath]);
    var root = roots.firstWhere(
        (r) => r.packagesFile.parent.path == packagePath,
        orElse: () => null);
    if (root == null) {
      log.warning(
          'No context root on the default path, selecting the one with the most files.');
      roots.sort((r1, r2) =>
          -r1.analyzedFiles().length.compareTo(r2.analyzedFiles().length));
      root = roots.first;
    }
    if (root == null) {
      throw StateError('No context root found!');
    }

    var analysisContext =
        ContextBuilder().createContext(contextRoot: root, sdkPath: dartSdkPath);

    return LibraryScanner._(
        packageName, packagePath, analysisContext.currentSession, overrides);
  }

  Future<Map<String, List<String>>> scanDirectLibs() => _scanPackage();

  Future<Map<String, List<String>>> scanTransitiveLibs() async {
    var results = SplayTreeMap<String, List<String>>();
    var direct = await _scanPackage();
    for (var key in direct.keys) {
      results[key] = await _scanTransitiveLibs(key, [key]);
    }
    return results;
  }

  Future<List<String>> _scanTransitiveLibs(
      String uri, List<String> stack) async {
    if (!_cachedTransitiveLibs.containsKey(uri)) {
      final processed = <String>{};
      final todo = <String>{uri};
      while (todo.isNotEmpty) {
        final lib = todo.first;
        todo.remove(lib);
        if (processed.contains(lib)) continue;
        processed.add(lib);
        if (!lib.startsWith('package:')) {
          // nothing to do
          continue;
        }
        // short-circuit when re-entrant call is detected
        if (stack.contains(lib)) {
          todo.addAll(await _scanUri(lib));
        } else {
          final newStack = List<String>.from(stack)..add(lib);
          processed.addAll(await _scanTransitiveLibs(lib, newStack));
        }
      }
      _applyOverrides(uri, processed);
      processed.remove(uri);
      _cachedTransitiveLibs[uri] = processed.toList()..sort();
    }
    return _cachedTransitiveLibs[uri];
  }

  Future<Map<String, List<String>>> scanDependencyGraph() async {
    var items = await scanTransitiveLibs();

    var graph = SplayTreeMap<String, List<String>>();

    var todo = LinkedHashSet<String>.from(items.keys);
    while (todo.isNotEmpty) {
      var first = todo.first;
      todo.remove(first);

      if (first.startsWith('dart:')) {
        continue;
      }

      graph.putIfAbsent(first, () {
        var cache = _cachedLibs[first];
        todo.addAll(cache);
        return cache;
      });
    }

    return graph;
  }

  Future<List<String>> _scanUri(String libUri) async {
    if (_cachedLibs.containsKey(libUri)) {
      return _cachedLibs[libUri];
    }
    var uri = Uri.parse(libUri);
    var package = uri.pathSegments.first;

    final fullPath = _session.uriConverter.uriToPath(uri);
    if (fullPath == null) {
      throw Exception('Could not resolve package URI for $uri');
    }

    var relativePath = p.join('lib', libUri.substring(libUri.indexOf('/') + 1));
    if (fullPath.endsWith('/$relativePath')) {
      var packageDir =
          fullPath.substring(0, fullPath.length - relativePath.length - 1);
      var libs = await _parseLibs(package, packageDir, relativePath);
      _cachedLibs[libUri] = libs;
      return libs;
    } else {
      return [];
    }
  }

  Future<Map<String, List<String>>> _scanPackage() async {
    var results = SplayTreeMap<String, List<String>>();
    await for (var relativePath
        in listFiles(_packagePath, endsWith: '.dart').where((path) {
      if (p.isWithin('bin', path)) {
        return true;
      }

      // Include all Dart files in lib – except for implementation files.
      if (p.isWithin('lib', path) && !p.isWithin('lib/src', path)) {
        return true;
      }

      return false;
    })) {
      var uri = toPackageUri(packageName, relativePath);
      if (_cachedLibs[uri] == null) {
        _cachedLibs[uri] =
            await _parseLibs(packageName, _packagePath, relativePath);
      }
      results[uri] = _cachedLibs[uri];
    }
    return results;
  }

  Future<List<String>> _parseLibs(
      String package, String packageDir, String relativePath) async {
    var fullPath = p.join(packageDir, relativePath);
    var lib = await _getLibraryElement(fullPath);
    if (lib == null) return [];
    var refs = SplayTreeSet<String>();
    lib.importedLibraries.forEach((le) {
      refs.add(_normalizeLibRef(le.librarySource.uri, package, packageDir));
    });
    lib.exportedLibraries.forEach((le) {
      refs.add(_normalizeLibRef(le.librarySource.uri, package, packageDir));
    });
    if (lib.hasExtUri) {
      refs.add('dart-ext:');
    }

    var pkgUri = toPackageUri(package, relativePath);
    _applyOverrides(pkgUri, refs);

    refs.remove('dart:core');
    return List<String>.unmodifiable(refs);
  }

  void _applyOverrides(String pkgUri, Set<String> set) {
    if (_overrides != null) {
      for (var override in _overrides) {
        if (override.uri == pkgUri) {
          if (set.remove(override.dependency) && override.overrideTo != null) {
            set.add(override.overrideTo);
          }
        }
      }
    }
  }

  Future<LibraryElement> _getLibraryElement(String path) async {
    var unitElement = await _session.getUnitElement(path);
    return unitElement.element.library;
  }
}

String _normalizeLibRef(Uri uri, String package, String packageDir) {
  if (uri.isScheme('file')) {
    var relativePath = p.relative(p.fromUri(uri), from: packageDir);
    return toPackageUri(package, relativePath);
  } else if (uri.isScheme('package') || uri.isScheme('dart')) {
    return uri.toString();
  }

  throw Exception('not supported - $uri');
}
