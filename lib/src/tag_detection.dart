// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:collection/collection.dart';
import 'package:pana/pana.dart';
import 'package:path/path.dart' as path;

abstract class Graph<T> {
  Set<T> directSuccessors(T t);
}

class FindPath<T> {
  final Graph<T> graph;
  final bool Function(T) predicate;
  final Map<T, PathResult<T>> _cache = <T, PathResult<T>>{};

  FindPath(this.graph, this.predicate);

  PathResult<T> findPath(T root) {
    final libraryStack = <T>[];
    final todo = <List<T>>[
      [root]
    ];
    final visited = <T>{};

    while (todo.isNotEmpty) {
      final x = todo.last;
      if (x.isEmpty) {
        todo.removeLast();
        if (todo.isNotEmpty) libraryStack.removeLast();
        continue;
      }
      final current = x.removeLast();

      if (visited.contains(current)) continue;
      visited.add(current);

      if (_cache.containsKey(current)) {
        return _cache[root] =
            PathResult.combine<T>(libraryStack, _cache[current]);
      }

      libraryStack.add(current);
      if (predicate(current)) {
        return PathResult<T>.path(libraryStack);
      }
      todo.add(graph.directSuccessors(current).toList());
    }
    return PathResult<T>.noPath();
  }
}

/// A graph of import/export dependencies for libraries under some configuration of
/// declared variables.
class LibraryGraph implements Graph<Uri> {
  final AnalysisSession _analysisSession;
  final Map<String, String> _declaredVariables;
  LibraryGraph(this._analysisSession, this._declaredVariables);
  final Map<Uri, Set<Uri>> _cache = <Uri, Set<Uri>>{};

  @override
  Set<Uri> directSuccessors(Uri uri) {
    return _cache.putIfAbsent(uri, () {
      if (uri.toString().startsWith('dart:')) {
        return <Uri>{};
      }
      final unitResult = _analysisSession.getParsedUnit(
        _analysisSession.uriConverter.uriToPath(uri),
      );
      if (unitResult.isPart || unitResult.unit == null) {
        // Part files cannot contain import/export directives.
        return null;
      }
      final dependencies = <Uri>{};
      for (final node in unitResult.unit.sortedDirectivesAndDeclarations) {
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
        var dependency = uri.resolve(directive.uri.stringValue);

        for (final configuration in directive.configurations) {
          final dottedName =
              configuration.name.components.map((i) => i.name).join('.');

          final testValue = configuration.value?.stringValue ?? 'true';
          final actualValue = _declaredVariables[dottedName] ?? 'false';

          if (actualValue == testValue) {
            dependency = uri.resolve(configuration.uri.stringValue);
            break; // always pick the first satisfied configuration
          }
        }

        //TODO: Determine if there is any need to normalize the `dependency` Uri.
        dependencies.add(dependency);
      }
      return dependencies;
    });
  }
}

class LibraryPackage {
  final AnalysisSession _analysisSession;
  LibraryPackage(this._analysisSession);
  String _packageDir(Uri uri) {
    final packageOnlyUri =
        uri.replace(path: uri.path.substring(0, uri.path.indexOf('/') + 1));
    return path
        .dirname(_analysisSession.uriConverter.uriToPath(packageOnlyUri));
  }

  final Map<String, Pubspec> _pubspecCache = <String, Pubspec>{};

  Pubspec pubspecOfLibrary(Uri uri) {
    return pubspecOfPackage(_packageDir(uri));
  }

  Pubspec pubspecOfPackage(String packageDir) {
    return _pubspecCache.putIfAbsent(packageDir, () {
      return Pubspec.parseFromDir(packageDir);
    });
  }
}

class Runtime {
  final String name;
  final Set<String> enabledLibs;

  Runtime(this.name, this.enabledLibs);

  Map<String, String> get declaredVariables =>
      {for (final lib in enabledLibs) 'dart.library.$lib': 'true'};

  @override
  toString() => 'Runtime($name)';

  static final _onAllPlatforms = {
    'async',
    'collection',
    'convert',
    'core',
    'developer',
    'math',
    'typed_data'
  };
  static final _onAllNative = {'io', 'isolate'};

  static final nativeJit = Runtime('native-jit', {
    ..._onAllPlatforms,
    ..._onAllNative,
    'mirrors',
    'developer',
  });
  static final nativeAot = Runtime('native-aot', {
    ..._onAllPlatforms,
    ..._onAllNative,
  });
  static final web = Runtime('web', {
    ..._onAllPlatforms,
    'html',
    'indexed_db',
    'web_audio',
    'web_gl',
    'js',
    'js_util',
    'web_sql',
  });
}

class PathResult<T> {
  final bool hasPath;
  final List<T> path;
  PathResult.noPath()
      : hasPath = false,
        path = null;
  PathResult.path(this.path) : hasPath = true;
  static PathResult<T> combine<T>(List<T> path, PathResult<T> other) {
    return other.hasPath
        ? PathResult.path([path, other.path].expand((x) => x).toList())
        : PathResult<T>.noPath();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathResult<T> &&
          other.hasPath == hasPath &&
          const ListEquality().equals(path, other.path);

  @override
  int get hashCode => hasPath.hashCode + const ListEquality().hash(path);

  @override
  String toString() =>
      hasPath ? 'RuntimeResult.path([$path])' : 'RuntimeResult.noPath()';
}

class RuntimeSupport {
  final FindPath<Uri> finder;

  RuntimeSupport(LibraryGraph resolver, Runtime runtime)
      : finder = FindPath<Uri>(resolver, (uri) {
          final uriString = uri.toString();
          return (uriString.startsWith('dart:') &&
              !runtime.enabledLibs.contains(uriString.substring(5)));
        });

  PathResult findRuntimeViolation(Uri root) {
    return finder.findPath(root);
  }
}

/// Does a depth-first traversal of the import-graph trying to find libraries
/// not allowed by [runtime].
///
/// Will initialize the analyzer with the declared variables from [runtime]
/// leading to configurable imports being resolved.
PathResult analyzeRuntimeSupport(String packageDir, Runtime runtime) {
  final analysisContext = ContextBuilder().createContext(
    contextRoot: ContextLocator().locateRoots(
      includedPaths: [packageDir],
    ).first,
  );
  final session = analysisContext.currentSession;
  final libraryPackage = LibraryPackage(session);
  final pubspec = libraryPackage.pubspecOfPackage(packageDir);
  final mainLibrary = Uri.parse('package:${pubspec.name}/${pubspec.name}.dart');
  return RuntimeSupport(
          LibraryGraph(session, runtime.declaredVariables), runtime)
      .findRuntimeViolation(mainLibrary);
}

List<String> runtimeTags(String packageDir) {
  final result = <String>[];
  for (final runtime in [Runtime.nativeAot, Runtime.nativeJit, Runtime.web]) {
    final analysisResult = analyzeRuntimeSupport(packageDir, runtime);
    if (!analysisResult.hasPath) {
      result.add('runtime:${runtime.name}');
    } else {
      print(
          'Runtime ${runtime.name} not supported. Because of the import path: ${analysisResult.path}');
    }
  }
  return result;
}

class FlutterPlatform {
  final String name;
  final Runtime runtime;
  FlutterPlatform(this.name, this.runtime);
  static final List<FlutterPlatform> possiblePlatforms = [
    FlutterPlatform('android', Runtime.nativeAot),
    FlutterPlatform('ios', Runtime.nativeAot),
    FlutterPlatform('windows', Runtime.nativeAot),
    FlutterPlatform('linux', Runtime.nativeAot),
    FlutterPlatform('macos', Runtime.nativeAot),
    FlutterPlatform('web', Runtime.web)
  ];
  @override
  String toString() => 'FlutterPlatform($name)';
}

class DeclaredFlutterPlatformDetector {
  final LibraryGraph dependencyResolver;
  final LibraryPackage libraryPackage;
  DeclaredFlutterPlatformDetector(this.dependencyResolver, this.libraryPackage);

  final Map<String, Set<FlutterPlatform>> _declaredPlatformCache =
      <String, Set<FlutterPlatform>>{};

  Set<FlutterPlatform> declaredFlutterPlatforms(String packageDir) {
    return _declaredPlatformCache.putIfAbsent(packageDir, () {
      final result = <FlutterPlatform>{};
      final fields = libraryPackage.pubspecOfPackage(packageDir).toJson();
      if (fields['flutter'] is! Map ||
          fields['flutter']['plugin'] is! Map ||
          fields['flutter']['plugin']['platforms'] is! Map) {
        return FlutterPlatform.possiblePlatforms.toSet();
      }
      final declaredPlatforms = fields['flutter']['plugin']['platforms'] as Map;
      for (final platform in FlutterPlatform.possiblePlatforms) {
        if (declaredPlatforms.containsKey(platform.name)) {
          result.add(platform);
        }
      }
      return result;
    });
  }
}

class PlatformViolationFinder {
  FindPath<Uri> declaredPlatformFinder;
  RuntimeSupport runtimeSupport;
  LibraryGraph resolver;
  DeclaredFlutterPlatformDetector platformDetector;
  PlatformViolationFinder(FlutterPlatform platform, this.resolver,
      this.platformDetector, LibraryPackage libraryPackage, this.runtimeSupport)
      : declaredPlatformFinder = FindPath(resolver, (uri) {
          return !(uri.scheme == 'dart') &&
              !platformDetector
                  .declaredFlutterPlatforms(libraryPackage._packageDir(uri))
                  .contains(platform);
        });

  PathResult findPlatformViolation(Uri root) {
    final declaredPlatformResult = declaredPlatformFinder.findPath(root);
    if (declaredPlatformResult.hasPath) {
      return declaredPlatformResult;
    }
    return runtimeSupport.findRuntimeViolation(root);
  }
}

List<String> flutterPlatformTags(String packageDir) {
  final result = <String>[];

  final pubspec = Pubspec.parseFromDir(packageDir);
  final mainLibrary = Uri.parse('package:${pubspec.name}/${pubspec.name}.dart');
  final analysisContext = ContextBuilder().createContext(
    contextRoot: ContextLocator().locateRoots(
      includedPaths: [packageDir],
    ).first,
  );

  final libraryPackage = LibraryPackage(analysisContext.currentSession);
  for (final flutterPlatform in FlutterPlatform.possiblePlatforms) {
    final session = analysisContext.currentSession;
    final resolver =
        LibraryGraph(session, flutterPlatform.runtime.declaredVariables);
    final violationFinder = PlatformViolationFinder(
        flutterPlatform,
        resolver,
        DeclaredFlutterPlatformDetector(resolver, libraryPackage),
        libraryPackage,
        RuntimeSupport(resolver, flutterPlatform.runtime));
    final pathResult = violationFinder.findPlatformViolation(mainLibrary);
    if (pathResult.hasPath) {
      print(
          '$packageDir does not support platform ${flutterPlatform.name} because of the import path ${pathResult.path}');
    } else {
      result.add('platform:${flutterPlatform.name}');
    }
  }
  return result;
}

main(List<String> args) {
  final packageDir = args.isNotEmpty
      ? args[0]
      : '/usr/local/google/home/sigurdm/projects/analyzer_configurable_imports/example';
  print(flutterPlatformTags(packageDir));
  print(runtimeTags(packageDir));
}
