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
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:pana/pana.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import 'logging.dart';

abstract class _DirectedGraph<T> {
  Set<T> directSuccessors(T t);
}

class _PathFinder<T> {
  final _DirectedGraph<T> graph;
  final bool Function(T) predicate;
  final Map<T, PathResult<T>> _cache = <T, PathResult<T>>{};

  _PathFinder(this.graph, this.predicate);

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
        return _cache[root] = _cache[current].prefix(libraryStack);
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
}

/// The dependency graph of a package.
///
/// Only considers non-dev-dependencies.
class _PackageGraph implements _DirectedGraph<String> {
  final _PubspecCache _pubspecCache;

  _PackageGraph(this._pubspecCache);

  @override
  Set<String> directSuccessors(String packageDir) {
    final pubspec = _pubspecCache.pubspecOfPackage(packageDir);
    return pubspec.dependencies.keys
        .map((name) => _pubspecCache._packageDir(Uri.parse('package:$name/')))
        // Probably a missing/broken dependency
        // TODO(sigurdm): figure out the right thing to do here.
        .where((x) => x != null)
        .toSet();
  }
}

/// Remembers parsed pubspecs.
///
/// Maps between library Uri's and package directories.
class _PubspecCache {
  final AnalysisSession _analysisSession;
  _PubspecCache(this._analysisSession);
  String _packageDir(Uri uri) {
    if (uri.scheme != 'package' && uri.scheme != null) {
      // We only resolve package: and relative uris.
      return null;
    }
    final packageOnlyUri =
        uri.replace(path: uri.path.substring(0, uri.path.indexOf('/') + 1));
    final filePath = _analysisSession.uriConverter.uriToPath(packageOnlyUri);
    // Could not resolve uri.
    // Probably a missing/broken dependency.
    // TODO(sigurdm): Figure out the right thing to do here.
    if (filePath == null) return null;
    return path.dirname(filePath);
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

/// Paths to all files matching `$packageDir/lib/**/*.dart`.
///
/// Paths are returned relative to `lib/`.
List<String> dartFilesFromLib(String packageDir) {
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
  final bool hasPath;
  final List<T> path;
  PathResult.noPath()
      : hasPath = false,
        path = null;
  PathResult.path(this.path) : hasPath = true;

  PathResult<T> prefix(List<T> prefix) {
    return hasPath
        ? PathResult.path([prefix, path].expand((x) => x).toList())
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

/// Detects forbidden imports given a runtime.
@visibleForTesting
class RuntimeViolationFinder {
  final _PathFinder<Uri> finder;

  RuntimeViolationFinder(LibraryGraph libraryGraph, Runtime runtime)
      : finder = _PathFinder<Uri>(libraryGraph, (uri) {
          final uriString = uri.toString();
          return (uriString.startsWith('dart:') &&
              !runtime.enabledLibs.contains(uriString.substring(5)));
        });

  PathResult findRuntimeViolation(Uri root) {
    return finder.findPath(root);
  }
}

/// A platform where Flutter can be deployed.
class FlutterPlatform {
  final String name;
  final Runtime runtime;
  FlutterPlatform(this.name, this.runtime);
  static final List<FlutterPlatform> recognizedPlatforms = [
    FlutterPlatform('android', Runtime.flutterNative),
    FlutterPlatform('ios', Runtime.flutterNative),
    FlutterPlatform('windows', Runtime.flutterNative),
    FlutterPlatform('linux', Runtime.flutterNative),
    FlutterPlatform('macos', Runtime.flutterNative),
    FlutterPlatform('web', Runtime.flutterWeb)
  ];
  @override
  String toString() => 'FlutterPlatform($name)';

  String get tag => 'platform:$name';
}

class _DeclaredFlutterPlatformDetector {
  final _PubspecCache _pubspecCache;
  final Map<String, Set<FlutterPlatform>> _declaredPlatformCache =
      <String, Set<FlutterPlatform>>{};

  _DeclaredFlutterPlatformDetector(this._pubspecCache);

  Set<FlutterPlatform> _declaredFlutterPlatforms(String packageDir) {
    return _declaredPlatformCache.putIfAbsent(packageDir, () {
      final result = <FlutterPlatform>{};
      final fields = _pubspecCache.pubspecOfPackage(packageDir).toJson();
      if (fields['flutter'] is! Map ||
          fields['flutter']['plugin'] is! Map ||
          fields['flutter']['plugin']['platforms'] is! Map) {
        return FlutterPlatform.recognizedPlatforms.toSet();
      }
      final declaredPlatforms = fields['flutter']['plugin']['platforms'] as Map;
      for (final platform in FlutterPlatform.recognizedPlatforms) {
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
  final RuntimeViolationFinder _runtimeSupport;
  final _DeclaredFlutterPlatformDetector platformDetector;

  _PlatformViolationFinder(
    FlutterPlatform platform,
    LibraryGraph libraryGraph,
    this.platformDetector,
    _PubspecCache libraryPackage,
    this._runtimeSupport,
  ) : declaredPlatformFinder = _PathFinder(libraryGraph, (uri) {
          final path = libraryPackage._packageDir(uri);
          // Could not resolve uri.
          // Probably a missing/broken dependency.
          // TODO(sigurdm): Figure out the right thing to do here.
          if (path == null) return false;
          return !(uri.scheme == 'dart') &&
              !platformDetector
                  ._declaredFlutterPlatforms(path)
                  .contains(platform);
        });

  PathResult _findPlatformViolation(Uri root) {
    final declaredPlatformResult = declaredPlatformFinder.findPath(root);
    if (declaredPlatformResult.hasPath) {
      return declaredPlatformResult;
    }
    return _runtimeSupport.findRuntimeViolation(root);
  }
}

class Sdk {
  final String name;
  final List<String> allowedSdks;
  final List<Runtime> allowedRuntimes;
  Sdk(this.name, this.allowedSdks, this.allowedRuntimes);

  String get tag => 'sdk:$name';

  static Sdk dart = Sdk(
      'dart', ['dart'], [Runtime.nativeAot, Runtime.nativeJit, Runtime.web]);
  static Sdk flutter = Sdk('flutter', ['dart', 'flutter'],
      [Runtime.flutterNative, Runtime.flutterWeb]);

  static List<Sdk> knownSdks = [dart, flutter];
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

class NullSafety {
  final _PathFinder<String> _languageVersionViolationFinder;
  final _PathFinder<String> _noOptoutViolationFinder;

  NullSafety(_PackageGraph packageGraph, _PubspecCache pubspecCache,
      AnalysisSession analysisSession)
      : _languageVersionViolationFinder =
            _PathFinder(packageGraph, (String packageDir) {
          final pubspec = pubspecCache.pubspecOfPackage(packageDir);
          return !pubspec.sdkConstraintStatus.hasOptedIntoNullSafety;
        }),
        _noOptoutViolationFinder =
            _PathFinder(packageGraph, (String packageDir) {
          final pubspec = pubspecCache.pubspecOfPackage(packageDir);
          for (final file in dartFilesFromLib(packageDir)) {
            final unit = _parsedUnitFromUri(
                analysisSession, Uri.parse('package:${pubspec.name}/$file'));
            if (unit == null) continue;
            final languageVersionToken = unit.languageVersionToken;
            if (languageVersionToken == null) continue;
            final version = Version.parse(
              '${languageVersionToken.major}.${languageVersionToken.minor}.0',
            );
            if (version < _firstVersionWithNullSafety) {
              return true;
            }
          }
          return false;
        });

  PathResult findNullSafetyViolation(String rootPackageDir) {
    final languageVersionResult =
        _languageVersionViolationFinder.findPath(rootPackageDir);
    if (languageVersionResult.hasPath) return languageVersionResult;
    return _noOptoutViolationFinder.findPath(rootPackageDir);
  }

  static final _firstVersionWithNullSafety = Version.parse('2.10.0');
}

/// Calculates the tags for the package residing in a given directory.
class Tagger {
  String packageDir;
  final AnalysisSession _session;
  final _PubspecCache _pubspecCache;
  final bool _isBinaryOnly;
  final List<Uri> _topLibraries;
  final _PackageGraph _packageGraph;

  Tagger._(this.packageDir, this._session, _PubspecCache pubspecCache,
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
    final pubspec = pubspecCache.pubspecOfPackage(packageDir);

    final libDartFiles = dartFilesFromLib(packageDir);
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
        packageDir, session, pubspecCache, isBinaryOnly, topLibraries);
  }

  Set<String> declaredSdks(String packageDir) {
    return {
      ..._pubspecCache.pubspecOfPackage(packageDir).dependentSdks,
      'dart'
    };
  }

  /// Returns `true` iff the package at [packageDir] supports [sdk].
  bool _supportsSdk(Sdk sdk) {
    if (_isBinaryOnly) {
      return sdk.name == 'dart';
    }
    if (_topLibraries.isEmpty) {
      return false;
    }
    // Will find a path in the package graph where a package declares an sdk
    // not supported by [sdk].
    final declaredSdkViolationFinder =
        _PathFinder(_packageGraph, (String packageDir) {
      return !declaredSdks(packageDir).every(sdk.allowedSdks.contains);
    });

    final pathResult = declaredSdkViolationFinder.findPath(packageDir);
    if (pathResult.hasPath) {
      log.info(
          '$packageDir does not support ${sdk.name} because of the package: ${pathResult.path}');
      return false;
    } else {
      for (final runtime in sdk.allowedRuntimes) {
        final finder = RuntimeViolationFinder(
            LibraryGraph(_session, runtime.declaredVariables), runtime);
        // check if all of the top libraries are supported
        var supports = true;
        for (final lib in _topLibraries) {
          final runtimePathResult = finder.findRuntimeViolation(lib);
          if (runtimePathResult.hasPath) {
            log.info(
                '$packageDir does not support ${sdk.name} with runtime: ${runtime.name} '
                'because of import violation at: ${runtimePathResult.path}');
            supports = false;
            break;
          }
        }
        if (supports) return true;
      }
      return false;
    }
  }

  List<String> sdkTags() {
    return Sdk.knownSdks.where(_supportsSdk).map((sdk) => sdk.tag).toList();
  }

  /// The Flutter platforms that this package works in.
  List<String> flutterPlatformTags() {
    if (_isBinaryOnly) {
      return <String>[];
    }
    if (_topLibraries.isEmpty) {
      return <String>[];
    }
    final result = <String>[];

    for (final flutterPlatform in FlutterPlatform.recognizedPlatforms) {
      final libraryGraph =
          LibraryGraph(_session, flutterPlatform.runtime.declaredVariables);
      final violationFinder = _PlatformViolationFinder(
          flutterPlatform,
          libraryGraph,
          _DeclaredFlutterPlatformDetector(_pubspecCache),
          _pubspecCache,
          RuntimeViolationFinder(libraryGraph, flutterPlatform.runtime));
      var supports = true;
      for (final lib in _topLibraries) {
        final pathResult = violationFinder._findPlatformViolation(lib);
        if (pathResult.hasPath) {
          log.info(
              '$packageDir does not support platform ${flutterPlatform.name} '
              'because of the import path ${pathResult.path}');
          supports = false;
          break;
        }
      }
      if (supports) {
        result.add(flutterPlatform.tag);
      }
    }
    return result;
  }

  /// The Dart runtimes that this package supports.
  ///
  /// Returns the empty list if this package does not support the dart sdk.
  List<String> runtimeTags() {
    if (_isBinaryOnly) {
      return <String>[Runtime.nativeAot.name, Runtime.nativeJit.name];
    }
    if (_topLibraries.isEmpty) {
      return <String>[];
    }
    if (!_supportsSdk(Sdk.dart)) return <String>[];
    final result = <String>[];
    for (final runtime in [Runtime.nativeAot, Runtime.nativeJit, Runtime.web]) {
      final finder = RuntimeViolationFinder(
          LibraryGraph(_session, runtime.declaredVariables), runtime);
      var supports = true;
      for (final lib in _topLibraries) {
        final pathResult = finder.findRuntimeViolation(lib);
        if (pathResult.hasPath) {
          log.info('$packageDir does not support runtime ${runtime.name} '
              'because of the import path: ${pathResult.path}');
          supports = false;
          break;
        }
      }
      if (supports) {
        result.add(runtime.tag);
      }
    }
    return result;
  }

  List<String> nullSafetyTags() {
    final nullSafety = NullSafety(_packageGraph, _pubspecCache, _session);
    final nullSafetyResult = nullSafety.findNullSafetyViolation(packageDir);
    if (nullSafetyResult.hasPath) {
      log.info(
          '$packageDir is not null-safety compliant because of ${nullSafetyResult.path}');
      return [];
    }
    return ['is:null-safety'];
  }
}
