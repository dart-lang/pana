// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/session.dart';

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

class DeclaredFlutterPlatformDetector {
  final PubspecCache _pubspecCache;
  final _declaredPlatformCache = <String, Set<FlutterPlatform>?>{};

  DeclaredFlutterPlatformDetector(this._pubspecCache);

  bool isFlutterPlugin(Uri uri) =>
      uri.scheme != 'package' ||
      _declaredFlutterPlatforms(_pubspecCache.packageName(uri)) != null;

  /// Returns the declared Flutter platforms if [packageName] is a plugin, and
  /// `null` otherwise.
  Set<FlutterPlatform>? _declaredFlutterPlatforms(String packageName) {
    return _declaredPlatformCache.putIfAbsent(packageName, () {
      final result = <FlutterPlatform>{};
      final fields = _pubspecCache.pubspecOfPackage(packageName).toJson();
      if (fields['flutter'] is! Map || fields['flutter']['plugin'] is! Map) {
        // If a package doesn't declare support for any platforms, it is
        // not a plugin, and can work on any platforms compatible with
        // imported constraints.
        return null;
      }
      final pluginMap = fields['flutter']['plugin'] as Map;
      final declaredPlatforms = pluginMap['platforms'];
      if (declaredPlatforms is Map) {
        for (final platform in FlutterPlatform.recognizedPlatforms) {
          if (declaredPlatforms.containsKey(platform.name.toLowerCase())) {
            result.add(platform);
          }
        }
      } else {
        // Legacy style plugin:
        if (pluginMap['pluginClass'] is String ||
            pluginMap['androidPackage'] is String ||
            pluginMap['iosPrefix'] is String) {
          result.add(FlutterPlatform.android);
          result.add(FlutterPlatform.ios);
        }
      }
      return result;
    });
  }
}

class PlatformViolationFinder {
  final PathFinder<Uri> declaredPlatformFinder;
  final PathFinder<Uri> _runtimeSupport;
  final DeclaredFlutterPlatformDetector platformDetector;

  PlatformViolationFinder(
    FlutterPlatform platform,
    LibraryGraph libraryGraph,
    this.platformDetector,
    PubspecCache pubspecCache,
    this._runtimeSupport,
  ) : declaredPlatformFinder = PathFinder(libraryGraph, (uri) {
          if (uri.scheme == 'package') {
            final detectedPlatforms = platformDetector
                ._declaredFlutterPlatforms(pubspecCache.packageName(uri));
            if (detectedPlatforms != null &&
                !detectedPlatforms.contains(platform)) {
              return (path) => Explanation(
                    'Package does not support Flutter platform ${platform.name}',
                    'Because:\n${LibraryGraph.formatPath(path)} that declares support for '
                        'platforms: ${detectedPlatforms.map((e) => e.name).join(', ')}',
                    tag: platform.tag,
                  );
            }
          }
          return null;
        });

  Explanation? findPlatformViolation(Uri root) {
    final declaredPlatformResult = declaredPlatformFinder.findViolation(root);
    return declaredPlatformResult ?? _runtimeSupport.findViolation(root);
  }
}

class SdkViolationFinder {
  final PathFinder<String> _declaredSdkViolationFinder;
  final List<PathFinder<Uri>> _allowedRuntimeViolationFinders;
  final Sdk sdk;

  SdkViolationFinder(PackageGraph packageGraph, this.sdk,
      PubspecCache pubspecCache, AnalysisSession session)
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
                      'Package not compatible with SDK ${sdk.name}',
                      'Because:\n${PackageGraph.formatPath(path)} that is a package requiring'
                          ' ${nonAllowedSdks.map((e) => null).join(', ')}.',
                      tag: sdk.tag,
                    );
          },
        ),
        _allowedRuntimeViolationFinders = sdk.allowedRuntimes
            .map((runtime) => runtimeViolationFinder(
                LibraryGraph(session, runtime.declaredVariables),
                runtime,
                (path) => Explanation(
                      'Package not compatible with sdk ${sdk.name} using runtime ${runtime.name}',
                      'Because:\n${LibraryGraph.formatPath(path)}',
                      tag: sdk.tag,
                    )))
            .toList();

  Explanation? findSdkViolation(String packageName, List<Uri> topLibraries) {
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
    return Explanation(
      'Package not compatible with SDK ${sdk.name}',
      'Because it is not compatible with any of the supported runtimes: '
          '${sdk.allowedRuntimes.map((r) => r.name).join(', ')}',
      tag: sdk.tag,
    );
  }
}
