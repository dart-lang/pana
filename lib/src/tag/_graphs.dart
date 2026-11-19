// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import '../logging.dart';
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

  String packageDir(String packageName) {
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
        return pubspecFromDir(packageDir(packageName));
      } on Exception catch (e) {
        throw TagException(e.toString());
      }
    });
  }
}

/// A parsed conditional import or export configuration
/// (`if (dottedName == testValue) uri`).
final class ParsedConfiguration {
  final String dottedName;
  final String testValue;
  final String? uri;

  const ParsedConfiguration({
    required this.dottedName,
    required this.testValue,
    required this.uri,
  });
}

/// A parsed `import` or `export` directive.
final class ParsedDirective {
  final String? uri;
  final List<ParsedConfiguration> configurations;

  const ParsedDirective({required this.uri, required this.configurations});
}

/// Lightweight metadata extracted from a parsed Dart compilation unit.
///
/// Retaining only directive and language-version metadata avoids keeping full
/// ASTs in memory while preventing repeated parsing across multiple
/// [LibraryGraph] configurations and tagging passes.
final class ParsedLibrary {
  static const empty = ParsedLibrary(directives: [], languageVersion: null);

  final List<ParsedDirective> directives;
  final Version? languageVersion;

  const ParsedLibrary({
    required this.directives,
    required this.languageVersion,
  });
}

/// Caches lightweight parsed metadata for Dart files in an [AnalysisSession].
final class ParsedLibraryCache {
  final AnalysisSession _analysisSession;
  final _cache = <String, ParsedLibrary>{};

  ParsedLibraryCache(this._analysisSession);

  /// Returns cached directive and language-version metadata for [filePath].
  ///
  /// Returns [ParsedLibrary.empty] if [filePath] has parse errors or is a part
  /// file.
  ParsedLibrary parseFile(String filePath) {
    return _cache.putIfAbsent(filePath, () {
      final unitResult =
          _analysisSession.getParsedUnit(filePath) as ParsedUnitResult;
      if (unitResult.diagnostics.isNotEmpty || unitResult.isPart) {
        // Ignore files with parse errors and part files (part files cannot
        // contain import/export directives or language-version overrides).
        return ParsedLibrary.empty;
      }

      final unit = unitResult.unit;
      final languageVersionToken = unit.languageVersionToken;
      final languageVersion = languageVersionToken == null
          ? null
          : Version(languageVersionToken.major, languageVersionToken.minor, 0);

      final directives = <ParsedDirective>[];
      for (final directive in unit.directives) {
        if (directive is! NamespaceDirective) continue;
        final configurations = directive.configurations.isEmpty
            ? const <ParsedConfiguration>[]
            : <ParsedConfiguration>[
                for (final configuration in directive.configurations)
                  ParsedConfiguration(
                    // Use lexemes to preserve source spelling of keywords such
                    // as `library` in `dart.library.js_interop`.
                    dottedName: configuration.name.tokens
                        .map((i) => i.lexeme)
                        .join(),
                    testValue: configuration.value?.stringValue ?? 'true',
                    uri: configuration.uri.stringValue,
                  ),
              ];
        directives.add(
          ParsedDirective(
            uri: directive.uri.stringValue,
            configurations: configurations,
          ),
        );
      }

      if (directives.isEmpty && languageVersion == null) {
        return ParsedLibrary.empty;
      }
      return ParsedLibrary(
        directives: directives.isEmpty ? const [] : directives,
        languageVersion: languageVersion,
      );
    });
  }
}

/// A graph of import/export dependencies for libraries under some configuration
/// of declared variables.
class LibraryGraph implements DirectedGraph<Uri> {
  final AnalysisSession _analysisSession;
  final Map<String, String> _declaredVariables;
  final Set<String> _disallowedConfigurationLibs;
  final Map<Uri, Set<Uri>> _cache = <Uri, Set<Uri>>{};
  final bool Function(Uri) _isLeaf;
  final ParsedLibraryCache _parsedLibraryCache;

  LibraryGraph(
    this._analysisSession,
    this._declaredVariables, {
    bool Function(Uri) isLeaf = _constantFalse,
    Set<String> disallowedConfigurationLibs = const {},
    ParsedLibraryCache? parsedLibraryCache,
  }) : _isLeaf = isLeaf,
       _disallowedConfigurationLibs = disallowedConfigurationLibs,
       _parsedLibraryCache =
           parsedLibraryCache ?? ParsedLibraryCache(_analysisSession);

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
    try {
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

        final filePath = _analysisSession.uriConverter.uriToPath(uri);
        if (filePath == null) {
          // Could not resolve uri.
          // Probably a missing/broken dependency.
          throw TagException('Could not resolve import: $uri');
        }
        final library = _parsedLibraryCache.parseFile(filePath);
        if (library.directives.isEmpty) {
          return <Uri>{};
        }
        final dependencies = <Uri>{};
        for (final directive in library.directives) {
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
          var dependency = uri.resolve(directive.uri!);
          Uri? disallowedConfigurationLibUri;

          for (final configuration in directive.configurations) {
            final dottedName = configuration.dottedName;
            final testValue = configuration.testValue;
            final actualValue = _declaredVariables[dottedName] ?? '';

            if (actualValue == testValue) {
              dependency = uri.resolve(configuration.uri!);
              if (_wasmWebConfigurationVars.contains(dottedName)) {
                disallowedConfigurationLibUri = null;
              }
              break; // Always pick the first satisfied configuration.
            }
            if (disallowedConfigurationLibUri == null &&
                testValue == 'true' &&
                dottedName.startsWith('dart.library.')) {
              final libName = dottedName.substring('dart.library.'.length);
              if (_disallowedConfigurationLibs.contains(libName)) {
                disallowedConfigurationLibUri = Uri.parse('dart:$libName');
              }
            }
          }

          dependencies.add(disallowedConfigurationLibUri ?? dependency);
        }
        return dependencies;
      });
    } catch (e) {
      log.info('Unable to parse "$uri".\n$e');
      throw TagException(
        'Unable to parse uri: "$uri": `${e.toString().split('\n').first}`.',
      );
    }
  }

  static String formatPath(List<Uri> path) {
    assert(path.isNotEmpty);
    return path.map((p) => '* `$p`').join(' that imports:\n');
  }

  static const _wasmWebConfigurationVars = {
    'dart.library.js_interop',
    'dart.library.js_interop_unsafe',
    'dart.library.ui_web',
  };

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

  /// Nodes from which no node satisfying [predicate] is reachable.
  ///
  /// Populated whenever a search completes without finding a match, so checking
  /// a sequence of roots until the first violation runs in O(V + E) total time.
  final _noPathNodes = <T>{};

  PathFinder(this.graph, this.predicate);

  /// Searches [graph] for nodes reachable from [root] to a node fulfilling
  /// [predicate].
  ///
  /// Uses depth-first search.
  PathResult<T> findPath(T root) {
    if (_noPathNodes.contains(root)) return PathResult<T>.noPath();
    final pathToCurrent = <T>[];
    final todo = <List<T>>[
      [root],
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

      if (_noPathNodes.contains(current)) continue;
      if (!visited.add(current)) continue;

      final explainer = predicate(current);
      if (explainer != null) {
        pathToCurrent.add(current);
        return PathResult<T>.path(pathToCurrent, explainer);
      }
      pathToCurrent.add(current);
      todo.add(graph.directSuccessors(current).toList());
    }
    _noPathNodes.addAll(visited);
    return PathResult<T>.noPath();
  }

  /// Finds a path from [root] to a node violating [predicate] and returns an
  /// [Explanation] indicating the issue.
  ///
  /// Returns `null` if no issue was found.
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
  PathResult.noPath() : path = null, explainer = null;
  PathResult.path(this.path, this.explainer)
    : assert(path != null),
      assert(explainer != null);

  Explanation? explain() => hasPath ? explainer!(path!) : null;
}
