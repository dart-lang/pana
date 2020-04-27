// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// # Package Classification
///
/// ## Dart Platform Detection
///
/// A package is tagged "sdk:dart" if the package dependency graph
///
/// * does not have any SDK constraints beyond `dart`.
/// * the primary library does not transitively import "dart:ui" when the
///   environment constant "dart.library.ui" is unset.
///
/// The **primary library** is the library with the same name as the package.
/// If there is no such library we analyse
///
/// If a package is tagged "sdk:dart" it may also be tagged by any of the
/// following runtime tags (corresponding to
/// https://dart.dev/guides/libraries):
///
/// * runtime:native-jit
///
///   Can be run with the dart vm in jit mode. (Can use dart:io and
///   dart:mirrors)
///
/// * runtime:native-aot
///   Can be aot compiled with eg. dart2native (Can use dart:io but not
///   dart:mirrors)
///
/// * runtime:web
///   Can be compiled with DDC and dart2js. (Can use dart:html and friends, not
///   dart:io, dart:mirrors, dart:ffi, etc.)
///
/// A package has the same runtime tags as the primary library.
///
/// ### Classification as "runtime:native-jit"
///
/// A library with tag sdk:dart is tagged runtime:native-jit, if when the
/// environment constants are:
///
/// * dart.library.io = 'true'
/// * dart.library.js = 'false' ...
///
/// it holds that:
///
/// * The library is not "dart:js", "dart:html", or friends;
/// * The library does not transitively import a library which does not have the
///   tag runtime:native-jit.
///   (other runtime tags are derived similarly).
///
/// ## Flutter Platform Detection
///
/// A package is tagged "sdk:flutter" if:
///
/// * the package dependency graph does not have any SDK constraints beyond
///   `dart` and `flutter`; and;
/// * the primary library does not transitively import "dart:mirrors" when the
///   environment constant "dart.library.mirrors = false" is set.
///
/// If a package is tagged "sdk:flutter" it may also be tagged by any of the
/// following platform tags (corresponding to the target platforms supported by
/// Flutter).
///
/// * platform:android
/// * platform:ios
/// * platform:web
/// * platform:windows
/// * platform:linux
/// * platform:macos
/// * platform:web
///
/// A package has the same platform tags as the primary library.

import 'dart:io';

import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:meta/meta.dart';
import 'package:pana/pana.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

abstract class _DirectedGraph<T> {
  Set<T> directSuccessors(T t);
}

/// Creates a suggestion indicating an issue, using [path] to give the location
/// of the issue.
typedef _Explainer<N> = Suggestion Function(List<N> path);

/// Returns an [_Explainer] if node fullfills the predicate (if it violates some
/// property) and `null` otherwise.
///
/// Explainer should give an explanation of the problem.
typedef _Predicate<T> = _Explainer<T> Function(T node);

class _PathFinder<T> {
  final _DirectedGraph<T> graph;
  final _Predicate<T> predicate;
  final Map<T, PathResult<T>> _cache = <T, PathResult<T>>{};

  _PathFinder(this.graph, this.predicate);

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
        return _cache[root] = _cache[current].prefix(pathToCurrent);
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
  /// suggestion indicating the issue.
  ///
  /// Returns `null` if no issue was found
  Suggestion findViolation(T root) => findPath(root).explain();
}

/// Returns a parsed (not resolved) compilation unit of [uri] created by
/// [analysisSession].
///
/// Returns `null` in case of any errors.
///
/// Returns `null` if [uri] points to a part file.
CompilationUnit _parsedUnitFromUri(AnalysisSession analysisSession, Uri uri) {
  final path = analysisSession.uriConverter.uriToPath(uri);
  if (path == null) {
    // Could not resolve uri.
    // Probably a missing/broken dependency.
    // TODO(sigurdm): Figure out the right thing to do here.
    return null;
  }
  final unitResult = analysisSession.getParsedUnit(path);
  if (unitResult.errors.isNotEmpty) return null;
  if (unitResult.isPart) {
    // Part files cannot contain import/export directives or language
    // directives.
    return null;
  }
  return unitResult.unit;
}

/// A graph of import/export dependencies for libraries under some configuration
/// of declared variables.
@visibleForTesting
class LibraryGraph implements _DirectedGraph<Uri> {
  final AnalysisSession _analysisSession;
  final Map<String, String> _declaredVariables;
  final Map<Uri, Set<Uri>> _cache = <Uri, Set<Uri>>{};

  LibraryGraph(this._analysisSession, this._declaredVariables);

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
      if (uriString.startsWith('dart:') || uriString.startsWith('dart-ext:')) {
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
        // TODO(sigurdm): Figure out the right thing to do here.
        return <Uri>{};
      }
      final unit = _parsedUnitFromUri(_analysisSession, uri);
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
        var dependency = uri.resolve(directive.uri.stringValue);

        for (final configuration in directive.configurations) {
          final dottedName =
              configuration.name.components.map((i) => i.name).join('.');

          final testValue = configuration.value?.stringValue ?? 'true';
          final actualValue = _declaredVariables[dottedName] ?? '';

          if (actualValue == testValue) {
            dependency = uri.resolve(configuration.uri.stringValue);
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
    if (path.length == 1) return 'the import of ${path.single}';
    return 'the import of ${path.last} via the import chain ${path.join('->')}';
  }
}

/// The dependency graph of a package.
///
/// A node is a package name as a String.
///
/// Only considers non-dev-dependencies.
class _PackageGraph implements _DirectedGraph<String> {
  final _PubspecCache _pubspecCache;

  _PackageGraph(this._pubspecCache);

  @override
  Set<String> directSuccessors(String packageName) {
    final pubspec = _pubspecCache.pubspecOfPackage(packageName);
    if (pubspec == null) {
      // Probably a missing/broken dependency
      // TODO(sigurdm): figure out the right thing to do here.
      return <String>{};
    }
    return pubspec.dependencies.keys.toSet();
  }

  static String formatPath(List<String> path) {
    assert(path.isNotEmpty);
    String prefix(String dep) => 'package:$dep';
    if (path.length == 1) {
      return prefix(path.single);
    } else {
      return '${prefix(path.last)} via dependency path: ${path.map(prefix).join('->')}';
    }
  }
}

/// Remembers parsed pubspecs.
///
/// Maps between library Uri's and package directories.
class _PubspecCache {
  final AnalysisSession _analysisSession;
  _PubspecCache(this._analysisSession);
  String _packageDir(String packageName) {
    final packageUri = Uri.parse('package:$packageName/');
    final filePath = _analysisSession.uriConverter.uriToPath(packageUri);
    // Could not resolve uri.
    // Probably a missing/broken dependency.
    // TODO(sigurdm): Figure out the right thing to do here.
    if (filePath == null) {
      throw ArgumentError('Could not find package dir of $packageName');
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

  final Map<String, Pubspec> _pubspecCache = <String, Pubspec>{};

  Pubspec pubspecOfLibrary(Uri uri) {
    return pubspecOfPackage(packageName(uri));
  }

  Pubspec pubspecOfPackage(String packageName) {
    return _pubspecCache.putIfAbsent(packageName, () {
      return Pubspec.parseFromDir(_packageDir(packageName));
    });
  }
}

/// Paths to all files matching `$packageDir/lib/**/*.dart`.
///
/// Paths are returned relative to `lib/`.
List<String> _dartFilesFromLib(String packageDir) {
  final libDir = Directory(path.join(packageDir, 'lib'));
  final libDirExists = libDir.existsSync();
  final dartFiles = libDirExists
      ? libDir
          .listSync(recursive: true)
          .where((e) => e is File && e.path.endsWith('.dart'))
          .map((f) => path.relative(f.path, from: libDir.path))
          .toList()
      : <String>[];

  // Sort to make the order of files and the reported events deterministic.
  dartFiles.sort();
  return dartFiles;
}

/// Represents a dart runtime and the `dart:` libraries available on that
/// platform.
@visibleForTesting
class Runtime {
  final String name;
  final Set<String> enabledLibs;

  Runtime(this.name, this.enabledLibs);

  Map<String, String> get declaredVariables =>
      {for (final lib in enabledLibs) 'dart.library.$lib': 'true'};

  @override
  String toString() => 'Runtime($name)';

  String get tag => 'runtime:$name';

  static final _onAllPlatforms = {
    'async',
    'collection',
    'convert',
    'core',
    'developer',
    'math',
    'typed_data',
    // TODO(sigurdm): Remove if/when package:dart_internal goes away.
    '_internal',
  };
  static final _onAllNative = {'ffi', 'io', 'isolate'};

  static final _onAllWeb = {
    'html',
    'indexed_db',
    'js',
    'js_util',
    'svg',
    'web_audio',
    'web_gl',
    'web_sql',
  };

  static final nativeJit = Runtime('native-jit', {
    ..._onAllPlatforms,
    ..._onAllNative,
    'cli',
    'developer',
    'mirrors',
    'nativewrappers',
  });

  static final nativeAot = Runtime('native-aot', {
    ..._onAllPlatforms,
    ..._onAllNative,
    'cli',
    'nativewrappers',
  });

  static final web = Runtime('web', {
    ..._onAllPlatforms,
    ..._onAllWeb,
    'html_common',
  });

  static final flutterNative = Runtime('flutter-native', {
    ..._onAllPlatforms,
    ..._onAllNative,
    'ui',
  });

  static final flutterWeb = Runtime('flutter-web', {
    ..._onAllPlatforms,
    ..._onAllWeb,
    'ui',
  });
}

/// The result of a path-finding.
///
/// Either there is no path or there is a path represented as the nodes on the
/// path including the starting node and the final node.
@visibleForTesting
class PathResult<T> {
  bool get hasPath => path != null;
  final List<T> path;
  final _Explainer<T> explainer;
  PathResult.noPath()
      : path = null,
        explainer = null;
  PathResult.path(this.path, this.explainer)
      : assert(path != null),
        assert(explainer != null);

  PathResult<T> prefix(List<T> prefix) {
    return hasPath
        ? PathResult.path([prefix, path].expand((x) => x).toList(), explainer)
        : PathResult<T>.noPath();
  }

  Suggestion explain() => hasPath ? explainer(path) : null;
}

/// Detects forbidden imports given a runtime.
@visibleForTesting
_PathFinder<Uri> runtimeViolationFinder(
    LibraryGraph libraryGraph, Runtime runtime, _Explainer<Uri> explainer) {
  return _PathFinder<Uri>(libraryGraph, (Uri uri) {
    final uriString = uri.toString();
    if (uriString.startsWith('dart:') &&
        !runtime.enabledLibs.contains(uriString.substring(5))) {
      return explainer;
    }
    return null;
  });
}

/// A platform where Flutter can be deployed.
class _FlutterPlatform {
  final String name;
  final Runtime runtime;
  _FlutterPlatform(this.name, this.runtime);
  static final List<_FlutterPlatform> recognizedPlatforms = [
    _FlutterPlatform('android', Runtime.flutterNative),
    _FlutterPlatform('ios', Runtime.flutterNative),
    _FlutterPlatform('windows', Runtime.flutterNative),
    _FlutterPlatform('linux', Runtime.flutterNative),
    _FlutterPlatform('macos', Runtime.flutterNative),
    _FlutterPlatform('web', Runtime.flutterWeb)
  ];
  @override
  String toString() => 'FlutterPlatform($name)';

  String get tag => 'platform:$name';
}

class _DeclaredFlutterPlatformDetector {
  final _PubspecCache _pubspecCache;
  final Map<String, Set<_FlutterPlatform>> _declaredPlatformCache =
      <String, Set<_FlutterPlatform>>{};

  _DeclaredFlutterPlatformDetector(this._pubspecCache);

  Set<_FlutterPlatform> _declaredFlutterPlatforms(String packageName) {
    return _declaredPlatformCache.putIfAbsent(packageName, () {
      final result = <_FlutterPlatform>{};
      final fields = _pubspecCache.pubspecOfPackage(packageName).toJson();
      if (fields['flutter'] is! Map ||
          fields['flutter']['plugin'] is! Map ||
          fields['flutter']['plugin']['platforms'] is! Map) {
        return _FlutterPlatform.recognizedPlatforms.toSet();
      }
      final declaredPlatforms = fields['flutter']['plugin']['platforms'] as Map;
      for (final platform in _FlutterPlatform.recognizedPlatforms) {
        if (declaredPlatforms.containsKey(platform.name)) {
          result.add(platform);
        }
      }
      return result;
    });
  }
}

class _PlatformViolationFinder {
  final _PathFinder<Uri> declaredPlatformFinder;
  final _PathFinder<Uri> _runtimeSupport;
  final _DeclaredFlutterPlatformDetector platformDetector;

  _PlatformViolationFinder(
    _FlutterPlatform platform,
    LibraryGraph libraryGraph,
    this.platformDetector,
    _PubspecCache pubspecCache,
    this._runtimeSupport,
  ) : declaredPlatformFinder = _PathFinder(libraryGraph, (uri) {
          if (uri.scheme == 'package' &&
              !platformDetector
                  ._declaredFlutterPlatforms(pubspecCache.packageName(uri))
                  .contains(platform)) {
            return (path) => Suggestion.hint(
                SuggestionCode.notCompatible,
                'Package does not support Flutter platform ${platform.name}',
                'Because of import path $path');
          }
          return null;
        });

  Suggestion _findPlatformViolation(Uri root) {
    final declaredPlatformResult = declaredPlatformFinder.findViolation(root);
    return declaredPlatformResult ?? _runtimeSupport.findViolation(root);
  }
}

class _SdkViolationFinder {
  final _PathFinder<String> _declaredSdkViolationFinder;
  final List<_PathFinder<Uri>> _allowedRuntimeViolationFinders;
  final _Sdk sdk;

  _SdkViolationFinder(_PackageGraph packageGraph, this.sdk,
      _PubspecCache pubspecCache, AnalysisSession session)
      : _declaredSdkViolationFinder = _PathFinder(
          packageGraph,
          (String packageDir) {
            final declaredSdks = {
              ...pubspecCache.pubspecOfPackage(packageDir).dependentSdks,
              'dart'
            };
            return declaredSdks.every(sdk.allowedSdks.contains)
                ? null
                : (path) => Suggestion.hint(
                    SuggestionCode.notCompatible,
                    'Package not compatible with SDK ${sdk.name}',
                    'because of import path $path');
          },
        ),
        _allowedRuntimeViolationFinders = sdk.allowedRuntimes
            .map((runtime) => runtimeViolationFinder(
                LibraryGraph(session, runtime.declaredVariables),
                runtime,
                (path) => Suggestion.hint(
                    SuggestionCode.notCompatible,
                    'Package not compatible with sdk ${sdk.name} using runtime ${runtime.name}',
                    'Because of import path ${LibraryGraph.formatPath(path)}')))
            .toList();

  Suggestion findSdkViolation(String packageName, List<Uri> topLibraries) {
    final declaredSdkResult =
        _declaredSdkViolationFinder.findViolation(packageName);
    if (declaredSdkResult != null) return declaredSdkResult;

    for (final finder in _allowedRuntimeViolationFinders) {
      // check if all of the top libraries are supported
      var supports = true;
      for (final lib in topLibraries) {
        final runtimeResult = finder.findViolation(lib);
        if (runtimeResult != null) {
          supports = false;
          break;
        }
      }
      if (supports) return null;
    }
    return Suggestion.hint(
      SuggestionCode.notCompatible,
      'Package not compatible with SDK ${sdk.name}',
      'Because it is not compatible with any of the supported runtimes: '
          '${sdk.allowedRuntimes.map((r) => r.name).join(', ')}',
    );
  }
}

class _Sdk {
  final String name;
  final List<String> allowedSdks;
  final List<Runtime> allowedRuntimes;
  _Sdk(this.name, this.allowedSdks, this.allowedRuntimes);

  String get tag => 'sdk:$name';

  static _Sdk dart = _Sdk(
      'dart', ['dart'], [Runtime.nativeAot, Runtime.nativeJit, Runtime.web]);
  static _Sdk flutter = _Sdk('flutter', ['dart', 'flutter'],
      [Runtime.flutterNative, Runtime.flutterWeb]);

  static List<_Sdk> knownSdks = [dart, flutter];
}

/// Decides if a package is null-safe.
///
/// A package is said to null-safety compliant if:
///
/// - The package has opted-in by specifying a lower dart sdk bound >= 2.10
/// - No libraries in the package opts out of the null-safety enabled language
///   version.
/// - All (non-dev) dependencies in the latest version resolvable by pub are
///   fully null-safety-compliant by this definition.

class _NullSafetyViolationFinder {
  final _PathFinder<String> _languageVersionViolationFinder;
  final _PathFinder<String> _noOptoutViolationFinder;

  _NullSafetyViolationFinder(_PackageGraph packageGraph,
      _PubspecCache pubspecCache, AnalysisSession analysisSession)
      : _languageVersionViolationFinder = _PathFinder<String>(packageGraph, (
          String packageDir,
        ) {
          final pubspec = pubspecCache.pubspecOfPackage(packageDir);

          return pubspec.sdkConstraintStatus.hasOptedIntoNullSafety
              ? null
              : (path) => Suggestion.hint(
                    SuggestionCode.notCompatible,
                    'Package is not null safe',
                    'Because of the language version from the sdk constraint '
                        'in pubspec.yaml of package '
                        '${_PackageGraph.formatPath(path)}',
                  );
        }),
        _noOptoutViolationFinder = _PathFinder(
          packageGraph,
          (packageName) {
            for (final file
                in _dartFilesFromLib(pubspecCache._packageDir(packageName))) {
              final unit = _parsedUnitFromUri(
                  analysisSession, Uri.parse('package:$packageName/$file'));
              if (unit == null) continue;
              final languageVersionToken = unit.languageVersionToken;
              if (languageVersionToken == null) continue;
              final version = Version.parse(
                '${languageVersionToken.major}.${languageVersionToken.minor}.0',
              );
              if (version < _firstVersionWithNullSafety) {
                return (path) => Suggestion.hint(
                      SuggestionCode.notCompatible,
                      'Package is not null safe',
                      'Because $file is opting out in package ${_PackageGraph.formatPath(path)}',
                    );
              }
            }
            return null;
          },
        );

  Suggestion findNullSafetyViolation(String rootPackageName) {
    return _languageVersionViolationFinder.findViolation(rootPackageName) ??
        _noOptoutViolationFinder.findViolation(rootPackageName);
  }

  static final _firstVersionWithNullSafety = Version.parse('2.10.0');
}

/// Calculates the tags for the package residing in a given directory.
class Tagger {
  final String packageName;
  final AnalysisSession _session;
  final _PubspecCache _pubspecCache;
  final bool _isBinaryOnly;
  final List<Uri> _topLibraries;
  final _PackageGraph _packageGraph;

  Tagger._(this.packageName, this._session, _PubspecCache pubspecCache,
      this._isBinaryOnly, this._topLibraries)
      : _pubspecCache = pubspecCache,
        _packageGraph = _PackageGraph(pubspecCache);

  /// Assumes that `pub get` has been run.
  factory Tagger(String packageDir) {
    final session = ContextBuilder()
        .createContext(
          contextRoot: ContextLocator().locateRoots(
            includedPaths: [packageDir],
          ).first,
        )
        .currentSession;
    final pubspecCache = _PubspecCache(session);
    final pubspec = Pubspec.parseFromDir(packageDir);

    final libDartFiles = _dartFilesFromLib(packageDir);
    final nonSrcDartFiles = libDartFiles.where((p) => !p.startsWith('src/'));

    Uri primaryLibrary;
    if (libDartFiles.contains('${pubspec.name}.dart')) {
      primaryLibrary =
          Uri.parse('package:${pubspec.name}/${pubspec.name}.dart');
    }

    // If there is a primary library, use it as a single source for top libraries,
    // otherwise take `lib/*.dart` or (if it was empty) `lib/**/*.dart`.
    List<Uri> topLibraries;
    if (primaryLibrary != null) {
      topLibraries = <Uri>[primaryLibrary];
    } else {
      topLibraries = (nonSrcDartFiles.isEmpty ? libDartFiles : nonSrcDartFiles)
          .map((name) => Uri.parse('package:${pubspec.name}/$name'))
          .toList();
    }

    final binDir = Directory(path.join(packageDir, 'bin'));
    final allBinFiles = binDir.existsSync()
        ? binDir
            .listSync(recursive: true)
            .where((e) => e is File && e.path.endsWith('.dart'))
            .map((f) => path.relative(f.path, from: binDir.path))
            .toList()
        : <String>[];
    final isBinaryOnly = nonSrcDartFiles.isEmpty && allBinFiles.isNotEmpty;

    return Tagger._(
        pubspec.name, session, pubspecCache, isBinaryOnly, topLibraries);
  }

  void sdkTags(List<String> tags, List<Suggestion> suggestions) {
    if (_isBinaryOnly) {
      tags.add('sdk:dart');
      Suggestion.hint(SuggestionCode.binaryOnly, 'Binary only',
          'Cannot assign flutter SDK tag because it is binary only');
    } else if (_topLibraries.isEmpty) {
      suggestions.add(
        Suggestion.hint(
            SuggestionCode.noToplevelLibraries,
            'No top-level libraries found',
            'Cannot assign sdk tags, because no .dart files where found in lib/'),
      );
    } else {
      for (final sdk in _Sdk.knownSdks) {
        // Will find a path in the package graph where a package declares an sdk
        // not supported by [sdk].
        final violationResult =
            _SdkViolationFinder(_packageGraph, sdk, _pubspecCache, _session)
                .findSdkViolation(packageName, _topLibraries);
        if (violationResult != null) {
          suggestions.add(violationResult);
        } else {
          tags.add(sdk.tag);
        }
      }
    }
  }

  /// Adds tags for the Flutter platforms that this package supports to [tags].
  ///
  /// Adds [Suggestion]s to [suggestions] for platforms not supported.
  void flutterPlatformTags(List<String> tags, List<Suggestion> suggestions) {
    if (_isBinaryOnly) {
      Suggestion.hint(SuggestionCode.binaryOnly, 'Binary only',
          'Cannot assign flutter platform tags, it is a binary only package');
    } else if (_topLibraries.isEmpty) {
      Suggestion.hint(
          SuggestionCode.noToplevelLibraries,
          'No top-level libraries found',
          'Cannot assign Flutter platform tags, because no .dart files were found in lib/');
    } else {
      for (final flutterPlatform in _FlutterPlatform.recognizedPlatforms) {
        final libraryGraph =
            LibraryGraph(_session, flutterPlatform.runtime.declaredVariables);
        final violationFinder = _PlatformViolationFinder(
            flutterPlatform,
            libraryGraph,
            _DeclaredFlutterPlatformDetector(_pubspecCache),
            _pubspecCache,
            runtimeViolationFinder(
                libraryGraph,
                flutterPlatform.runtime,
                (List<Uri> path) => Suggestion.hint(
                    SuggestionCode.notCompatible,
                    'Package not compatible with runtime ${flutterPlatform.runtime.name} of ${flutterPlatform.name}',
                    'Because of ${LibraryGraph.formatPath(path)}')));
        var supports = true;
        for (final lib in _topLibraries) {
          final violationResult = violationFinder._findPlatformViolation(lib);
          if (violationResult != null) {
            suggestions.add(violationResult);
            supports = false;
            break;
          }
        }
        if (supports) {
          tags.add(flutterPlatform.tag);
        }
      }
    }
  }

  /// Adds tags for the Dart runtimes that this package supports to [tags].
  ///
  /// Adds [Suggestion]s to [suggestions] for runtimes not supported.
  void runtimeTags(List<String> tags, List<Suggestion> suggestions) {
    if (_isBinaryOnly) {
      tags.addAll(<String>[Runtime.nativeAot.name, Runtime.nativeJit.name]);
    } else if (_topLibraries.isEmpty) {
      Suggestion.hint(
          SuggestionCode.noToplevelLibraries,
          'No top-level libraries found',
          'Cannot assign runtime tags, because no .dart files where found in lib/');
    } else {
      final dartSdkViolationFinder = _SdkViolationFinder(
          _packageGraph, _Sdk.dart, _pubspecCache, _session);
      if (dartSdkViolationFinder.findSdkViolation(packageName, _topLibraries) !=
          null) {
        // This is reported elsewhere
      } else {
        for (final runtime in [
          Runtime.nativeAot,
          Runtime.nativeJit,
          Runtime.web
        ]) {
          final finder = runtimeViolationFinder(
              LibraryGraph(_session, runtime.declaredVariables),
              runtime,
              (List<Uri> path) => Suggestion.hint(
                  SuggestionCode.notCompatible,
                  'Package not compatible with runtime ${runtime.name}',
                  'Because of ${LibraryGraph.formatPath(path)}'));
          var supports = true;
          for (final lib in _topLibraries) {
            final violationResult = finder.findViolation(lib);
            if (violationResult != null) {
              suggestions.add(violationResult);
              supports = false;
              break;
            }
          }
          if (supports) {
            tags.add(runtime.tag);
          }
        }
      }
    }
  }

  void nullSafetyTags(List<String> tags, List<Suggestion> suggestions) {
    final nullSafety =
        _NullSafetyViolationFinder(_packageGraph, _pubspecCache, _session);
    final nullSafetyResult = nullSafety.findNullSafetyViolation(packageName);
    if (nullSafetyResult != null) {
      suggestions.add(nullSafetyResult);
    } else {
      return tags.add('is:null-safe');
    }
  }
}
