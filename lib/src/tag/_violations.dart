// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Detection of platform support
///
/// We define two concepts:
///
/// * Platforms supported by a dart library.
/// * Platforms supported by a package.
///
/// These are two separate concepts.
///
/// We start by defining the set of platforms supported by a library, because a
/// package may contain multiple libraries, hence, the first definition (1) will
/// be helpful for defining platforms supported by a package (2). On the pub.dev
/// site, when searching / filtering packages, it is always definition (2): the
/// set of platforms that is supported by a package that will be used and
/// presented to the user. Platforms supported by a library is an internal
/// technicality used to formally define how supported platforms for a package
/// are derived.
///
/// Definition 1: Platforms supported for a given dart **library**
///
/// We say that platform linux is supported by library foo.dart if and only if
/// for all libraries bar.dart in the transitive import-graph of foo.dart on
/// platform linux it holds that:
///
/// * The library bar.dart does NOT import any platform specific Dart SDK
///   library not supported on platform linux.
/// * The library bar.dart does not exists inside a package where:
///   * platforms in pubspec.yaml is defined, and,
///   * platforms.linux is not defined.
/// * The library bar.dart does not exists inside a package where:
///   * flutter.plugin.platforms in pubspec.yaml is defined, and,
///   * flutter.plugin.platforms.linux is not defined.
///
/// (In this definition, the transitive import-graph depends on the platform in
/// question as we need to account for conditional-imports, furthermore the
/// transitive import-graph of library foo.dart includes the library itself
/// foo.dart).
///
/// Definition 2: Platforms support for a given **package**
///
/// We say that platform linux supported by package:foo if and only if either:
///
/// * platforms.linux is defined in pubspec.yaml; or
/// * platforms is not defined in pubspec.yaml and
///   flutter.plugin.platforms.linux is defined; or
/// * It holds that:
///   * platforms is not defined in pubspec.yaml,
///   * flutter.plugin.platforms is not defined in pubspec.yaml, and,
///   * The platform linux is supported by the library package:foo/foo.dart
///     following definition 1.
/// * It holds that:
///   * platforms is not defined in pubspec.yaml,
///   * flutter.plugin.platforms is not defined in pubspec.yaml,
///   * The library package:foo/foo.dart is not defined, and,
///   * All public libraries in package:foo/** (excluding package:foo/src/)
///     support linux.
///
/// Reasoning: unless a package explicitly declares what platforms it supports,
/// the set of supported platforms depends on the transitive-import graph for
/// the default library. Even if an imported library bar.dart exists within
/// another package foo that explicitly states that it supports linux, the
/// transitive-import graph from bar.dart still needs to be considered because
/// even if package foo containing bar.dart explicitly supports linux, that does
/// not necessarily mean that all libraries within package foo (such as
/// bar.dart) supports linux.
///
/// It is expected that when package foo declares explicit support for linux,
/// then package:foo/foo.dart works on linux. But it is also reasonable that
/// package foo may contain additional public libraries such as
/// package:foo/foo_js.dart which may not work on linux. This pattern is
/// commonly used to expose cross-platform features from the default library
/// package:foo/foo.dart, while allowing platform specific features to still be
/// supported in auxiliary libraries which may be conditionally imported, or
/// completely avoided if said features are not needed (hence, increase range of
/// supported platforms).
///
/// If both "platforms" and "flutter.platforms" are declared "platforms" takes
/// precedence. (There might be rare cases where you want to declare a more
/// narrow set of platforms than you have plugin support for).
library;

import 'package:analyzer/dart/analysis/session.dart';

import '../tool/run_proc.dart' show ToolException;
import '_common.dart';
import '_graphs.dart';
import '_specs.dart';

/// Detects forbidden imports given a runtime.
PathFinder<Uri> runtimeViolationFinder(
    LibraryGraph libraryGraph, Runtime runtime, Explainer<Uri> explainer) {
  return PathFinder<Uri>(libraryGraph, (Uri uri) {
    final uriString = uri.toString();
    if (uriString.startsWith('dart:') &&
        !runtime.enabledLibs.contains(uriString.substring(5))) {
      return explainer;
    }
    return null;
  });
}

class DeclaredPlatformDetector {
  final PubspecCache _pubspecCache;
  final _declaredPlatformCache = <String, Set<Platform>?>{};

  DeclaredPlatformDetector(this._pubspecCache);

  bool hasDeclaredPlatforms(Uri uri) =>
      uri.scheme != 'package' ||
      _declaredPlatforms(_pubspecCache.packageName(uri)) != null;

  /// Returns the declared platforms if [packageName] has a top-level platform
  /// tag or is a Flutter plugin with declared platforms and `null` otherwise.
  Set<Platform>? _declaredPlatforms(String packageName) {
    return _declaredPlatformCache.putIfAbsent(packageName, () {
      final fields = _pubspecCache.pubspecOfPackage(packageName).toJson();
      if (fields['platforms'] is Map) {
        final result = <Platform>{};

        final declaredPlatforms = fields['platforms'] as Map;
        for (final platform in Platform.recognizedPlatforms) {
          if (declaredPlatforms.containsKey(platform.name.toLowerCase())) {
            result.add(platform);
          }
        }
        return result;
      } else if (fields['flutter'] is Map &&
          fields['flutter']['plugin'] is Map) {
        final result = <Platform>{};

        final pluginMap = fields['flutter']['plugin'] as Map;
        final declaredPlatforms = pluginMap['platforms'];
        if (declaredPlatforms is Map) {
          for (final platform in Platform.recognizedPlatforms) {
            if (declaredPlatforms.containsKey(platform.name.toLowerCase())) {
              result.add(platform);
            }
          }
        } else {
          // Legacy style plugin:
          if (pluginMap['pluginClass'] is String ||
              pluginMap['androidPackage'] is String ||
              pluginMap['iosPrefix'] is String) {
            result.add(Platform.android);
            result.add(Platform.ios);
          }
        }
        return result;
      } else {
        return null;
      }
    });
  }
}

class PlatformViolationFinder {
  final Platform platform;
  final PathFinder<String> _packageDeclaredFinder;
  final PathFinder<Uri> _libraryDeclaredFinder;
  final PathFinder<Uri> _runtimeSupport;
  final DeclaredPlatformDetector platformDetector;

  PlatformViolationFinder(
    this.platform,
    LibraryGraph libraryGraph,
    this.platformDetector,
    PubspecCache pubspecCache,
    this._runtimeSupport,
  )   : _packageDeclaredFinder =
            PathFinder(PackageGraph(pubspecCache), (package) {
          final detectedPlatforms =
              platformDetector._declaredPlatforms(package);
          if (detectedPlatforms != null &&
              !detectedPlatforms.contains(platform)) {
            return (path) => Explanation(
                  'Package does not support platform `${platform.name}`.',
                  'Because:\n${PackageGraph.formatPath(path)} that declares support for '
                      'platforms: ${detectedPlatforms.map((e) => '`${e.name}`').join(', ')}.',
                  tag: platform.tag,
                );
          }
          return null;
        }),
        _libraryDeclaredFinder = PathFinder(libraryGraph, (uri) {
          if (uri.scheme == 'package') {
            final detectedPlatforms = platformDetector
                ._declaredPlatforms(pubspecCache.packageName(uri));
            if (detectedPlatforms != null &&
                !detectedPlatforms.contains(platform)) {
              return (path) => Explanation(
                    'Package does not support platform `${platform.name}`.',
                    'Because:\n${LibraryGraph.formatPath(path)} that declares support for '
                        'platforms: ${detectedPlatforms.map((e) => '`${e.name}`').join(', ')}.',
                    tag: platform.tag,
                  );
            }
          }
          return null;
        });

  /// Returns the first platform violation using the transitive dependencies of
  /// [topLibraries] or, if no such library is present, using the declared
  /// platforms from the [package]'s `pubspec.yaml`.
  Explanation? firstViolation(String package, List<Uri> topLibraries) {
    if (topLibraries.isEmpty) {
      return _packageDeclaredFinder.findViolation(package);
    } else {
      for (final uri in topLibraries) {
        final e = _findPlatformViolation(uri);
        if (e != null) return e;
      }
    }
    return null;
  }

  Explanation? _findPlatformViolation(Uri root) {
    try {
      final declaredPlatformResult = _libraryDeclaredFinder.findViolation(root);
      return declaredPlatformResult ?? _runtimeSupport.findViolation(root);
    } on ToolException catch (e) {
      return Explanation('Unable to verify', '$e', tag: platform.tag);
    }
  }
}

class SdkViolationFinder {
  final PathFinder<String> _declaredSdkViolationFinder;
  final Sdk sdk;
  final AnalysisSession _session;

  SdkViolationFinder(PackageGraph packageGraph, this.sdk,
      PubspecCache pubspecCache, this._session)
      : _declaredSdkViolationFinder = PathFinder(
          packageGraph,
          (String packageDir) {
            final declaredSdks = {
              ...pubspecCache.pubspecOfPackage(packageDir).dependentSdks,
              'dart'
            };
            final nonAllowedSdks =
                declaredSdks.difference(sdk.allowedSdks.toSet());
            return nonAllowedSdks.isEmpty
                ? null
                : (path) => Explanation(
                      'Package is not compatible with the ${sdk.formattedName} SDK.',
                      'Because:\n${PackageGraph.formatPath(path)} that is a package requiring'
                          ' ${nonAllowedSdks.join(', ')}.',
                      tag: sdk.tag,
                    );
          },
        );

  Explanation? findSdkViolation(String packageName, List<Uri> topLibraries) {
    final declaredSdkResult =
        _declaredSdkViolationFinder.findViolation(packageName);
    if (declaredSdkResult != null) return declaredSdkResult;

    final explanations = <Explanation>[];
    final violationFinder = runtimeViolationFinder(
      LibraryGraph(_session, sdk.allowedRuntime.declaredVariables),
      sdk.allowedRuntime,
      (path) => Explanation(
        'Package is not compatible with the ${sdk.formattedName} SDK.',
        'Because:\n${LibraryGraph.formatPath(path)}',
        tag: sdk.tag,
      ),
    );

    // check if all of the top libraries are supported
    var supports = true;
    for (final lib in topLibraries) {
      try {
        final runtimeResult = violationFinder.findViolation(lib);
        if (runtimeResult != null) {
          explanations.add(runtimeResult);
          supports = false;
          break;
        }
      } on ToolException catch (e) {
        return Explanation('Unable to verify `$lib`.', '$e', tag: sdk.tag);
      }
    }
    if (supports) return null;
    return Explanation(
      'Package is not compatible with the ${sdk.formattedName} SDK.',
      explanations.map((e) => '${e.finding} ${e.explanation}').join('\n\n'),
      tag: sdk.tag,
    );
  }
}
