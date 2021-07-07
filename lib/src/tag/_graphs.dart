// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;

import '../pubspec.dart';
import '../pubspec_io.dart' show pubspecFromDir;
import '_common.dart';

abstract class DirectedGraph<T> {
  Set<T> directSuccessors(T t);
}

/// Remembers parsed pubspecs.
///
/// Maps between library Uri's and package directories.
class PubspecCache {
  final AnalysisSession _analysisSession;
  final _pubspecs = <String, Pubspec>{};

  PubspecCache(this._analysisSession);

  String _packageDir(String packageName) {
    final packageUri = Uri.parse('package:$packageName/');
    final filePath = _analysisSession.uriConverter.uriToPath(packageUri);
    // Could not resolve uri.
    // Probably a missing/broken dependency.
    if (filePath == null) {
      throw TagException('Could not find package dir of $packageName');
    }
    return path.dirname(filePath);
  }

  String packageName(Uri uri) {
    if (uri.scheme != 'package') {
      // We only resolve package: uris.
      throw ArgumentError('Trying to get the package name of $uri');
    }
    return uri.pathSegments.first;
  }

  Pubspec pubspecOfLibrary(Uri uri) {
    return pubspecOfPackage(packageName(uri));
  }

  Pubspec pubspecOfPackage(String packageName) {
    return _pubspecs.putIfAbsent(packageName, () {
      try {
        return pubspecFromDir(_packageDir(packageName));
      } on Exception catch (e) {
        throw TagException(e.toString());
      }
    });
  }
}

/// A graph of import/export dependencies for libraries under some configuration
/// of declared variables.
class LibraryGraph implements DirectedGraph<Uri> {
  final AnalysisSession _analysisSession;
  final Map<String, String> _declaredVariables;
  final Map<Uri, Set<Uri>> _cache = <Uri, Set<Uri>>{};
  final bool Function(Uri) _isLeaf;

  LibraryGraph(
    this._analysisSession,
    this._declaredVariables, {
    bool Function(Uri) isLeaf = _constantFalse,
  }) : _isLeaf = isLeaf;

  /// The direct successors of the library [uri] are the libraries imported or
  /// exported by that library.
  ///
  /// Part files have no successors.
  ///
  /// For the purposes of our analysis `dart:` and `dart-ext:` libraries have no
  /// successors.
  ///
  /// For the purposes of our analysis any library in package:flutter has
  /// `dart:ui` as their only successor.
  @override
  Set<Uri> directSuccessors(Uri uri) {
    return _cache.putIfAbsent(uri, () {
      final uriString = uri.toString();
      if (uriString.startsWith('dart:') ||
          uriString.startsWith('dart-ext:') ||
          _isLeaf(uri)) {
        return <Uri>{};
      }
      // HACK: package:flutter comes from the SDK, we do not want to look at its
      // import graph.
      //
      // We need this because package:flutter imports dart:io, even though it is
      // allowed on web.
      if (uriString.startsWith('package:flutter/')) {
        return <Uri>{Uri.parse('dart:ui')};
      }

      final path = _analysisSession.uriConverter.uriToPath(uri);
      if (path == null) {
        // Could not resolve uri.
        // Probably a missing/broken dependency.
        throw TagException('Could not resolve import: $uri');
      }
      final unit = parsedUnitFromUri(_analysisSession, uri);
      if (unit == null) {
        // Part files cannot contain import/export directives.
        return <Uri>{};
      }
      final dependencies = <Uri>{};
      for (final node in unit.sortedDirectivesAndDeclarations) {
        if (node is! ImportDirective && node is! ExportDirective) {
          continue;
        }
        // The syntax for an import:
        //
        //    directive ::=
        //        'import' stringLiteral (configuration)*
        //      | 'export' stringLiteral (configuration)*
        //
        //    configuration ::= 'if' '(' test ')' uri
        //
        //    test ::= dottedName ('==' stringLiteral)?
        //
        // We have dependency upon `directive.uri` resolved relative to this
        // library `uri`. Unless there is a `configuration` for which the `test`
        // evaluates to true.
        final directive = node as NamespaceDirective;
        var dependency = uri.resolve(directive.uri.stringValue!);

        for (final configuration in directive.configurations) {
          final dottedName =
              configuration.name.components.map((i) => i.name).join('.');

          final testValue = configuration.value?.stringValue ?? 'true';
          final actualValue = _declaredVariables[dottedName] ?? '';

          if (actualValue == testValue) {
            dependency = uri.resolve(configuration.uri.stringValue!);
            break; // Aways pick the first satisfied configuration.
          }
        }

        dependencies.add(dependency);
      }
      return dependencies;
    });
  }

  static String formatPath(List<Uri> path) {
    assert(path.isNotEmpty);
    return path.map((p) => '* `$p`').join(' that imports:\n');
  }

  static bool _constantFalse(Uri _) => false;
}

/// The dependency graph of a package.
///
/// A node is a package name as a String.
///
/// Only considers non-dev-dependencies.
class PackageGraph implements DirectedGraph<String> {
  final PubspecCache _pubspecCache;

  PackageGraph(this._pubspecCache);

  @override
  Set<String> directSuccessors(String packageName) {
    final pubspec = _pubspecCache.pubspecOfPackage(packageName);
    return pubspec.dependencies.keys.toSet();
  }

  static String formatPath(List<String> path) {
    assert(path.isNotEmpty);
    return path.map((p) => '* `$p`').join(' that depends on:\n');
  }
}

class PathFinder<T> {
  final DirectedGraph<T> graph;
  final Predicate<T> predicate;
  final Map<T, PathResult<T>> _cache = <T, PathResult<T>>{};

  PathFinder(this.graph, this.predicate);

  /// Searches [graph] for nodes reachable from [root] to a node full-filling
  /// [predicate].
  ///
  /// Uses depth-first search.
  PathResult<T> findPath(T root) {
    final pathToCurrent = <T>[];
    final todo = <List<T>>[
      [root]
    ];
    final visited = <T>{};

    while (todo.isNotEmpty) {
      final x = todo.last;
      if (x.isEmpty) {
        todo.removeLast();
        if (todo.isNotEmpty) pathToCurrent.removeLast();
        continue;
      }
      final current = x.removeLast();

      if (!visited.add(current)) continue;

      if (_cache.containsKey(current)) {
        return _cache[root] = _cache[current]!.prefix(pathToCurrent);
      }

      pathToCurrent.add(current);
      final explainer = predicate(current);
      if (explainer == null) {
        todo.add(graph.directSuccessors(current).toList());
      } else {
        return PathResult<T>.path(pathToCurrent, explainer);
      }
    }
    return PathResult<T>.noPath();
  }

  /// Finds a path from [root] to a node violating of [predicate] and returns a
  /// Explanation indicating the issue.
  ///
  /// Returns `null` if no issue was found
  Explanation? findViolation(T root) => findPath(root).explain();
}

/// The result of a path-finding.
///
/// Either there is no path or there is a path represented as the nodes on the
/// path including the starting node and the final node.
class PathResult<T> {
  bool get hasPath => path != null;
  final List<T>? path;
  final Explainer<T>? explainer;
  PathResult.noPath()
      : path = null,
        explainer = null;
  PathResult.path(this.path, this.explainer)
      : assert(path != null),
        assert(explainer != null);

  PathResult<T> prefix(List<T> prefix) {
    return hasPath
        ? PathResult.path([...prefix, ...path!], explainer)
        : PathResult<T>.noPath();
  }

  Explanation? explain() => hasPath ? explainer!(path!) : null;
}
