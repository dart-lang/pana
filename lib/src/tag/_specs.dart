// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'pana_tags.dart';

/// Represents a dart runtime and the `dart:` libraries available on that
/// platform.
class Runtime {
  final String name;
  final Set<String> enabledLibs;
  final String tag;

  Runtime(this.name, this.enabledLibs, {required this.tag});

  Map<String, String> get declaredVariables =>
      {for (final lib in enabledLibs) 'dart.library.$lib': 'true'};

  @override
  String toString() => 'Runtime($name)';

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

  static final _onNativeAot = {
    ..._onAllPlatforms,
    ..._onAllNative,
    'cli',
    'developer',
  };

  static final _onNativeJit = {
    ..._onNativeAot,
    'mirrors',
    'nativewrappers',
  };

  static final nativeJit =
      Runtime('vm-native', _onNativeJit, tag: PanaTags.runtimeNativeJit);

  static final recognizedRuntimes = [
    nativeAot,
    nativeJit,
    web,
  ];

  static final nativeAot = Runtime(
    'native-aot',
    {
      ..._onAllPlatforms,
      ..._onAllNative,
      'cli',
      'nativewrappers',
    },
    tag: PanaTags.runtimeNativeAot,
  );

  static final web = Runtime(
    'js',
    {
      ..._onAllPlatforms,
      ..._onAllWeb,
      'html_common',
    },
    tag: PanaTags.runtimeWeb,
  );

  static final flutterNative = Runtime(
    'flutter-native',
    {
      ..._onAllPlatforms,
      ..._onAllNative,
      'ui',
    },
    tag: PanaTags.runtimeFlutterNative,
  );

  static final flutterWeb = Runtime(
    'flutter-web',
    {
      ..._onAllPlatforms,
      ..._onAllWeb,
      'ui',
    },
    tag: PanaTags.runtimeFlutterWeb,
  );

  /// For platform detection we allow dart:ui.
  static final broadWeb = Runtime(
    'web',
    {
      ..._onAllPlatforms,
      ..._onAllWeb,
      'ui',
    },
    tag: PanaTags.runtimeWeb,
  );

  /// For platform detection we allow dart:ui.
  static final broadNative = Runtime(
    'native',
    {
      ..._onAllPlatforms,
      ..._onAllNative,
      'ui',
    },
    tag: PanaTags.runtimeNative,
  );

  /// For sdk detection we allow everything except dart:ui.
  static final broadDart = Runtime(
    'dart',
    {..._onNativeJit, ..._onAllWeb},
    tag: PanaTags.runtimeDart,
  );

  /// For sdk detection we allow more or less everything.
  static final broadFlutter = Runtime(
    'flutter',
    {
      ..._onNativeAot,
      ..._onAllWeb,
      'ui',
    },
    tag: PanaTags.runtimeFlutter,
  );
}

/// A platform where Dart and Flutter can be deployed.
class Platform {
  final String name;
  final Runtime? dartRuntime;
  final Runtime flutterRuntime;
  final String tag;

  Platform(
    this.name, {
    required this.dartRuntime,
    required this.flutterRuntime,
    required this.tag,
  });

  static final List<Platform> recognizedPlatforms = [
    android,
    ios,
    windows,
    linux,
    macos,
    web,
  ];

  /// Platforms that binary-only packages will be assigned to.
  static final binaryOnlyAssignedPlatforms = [
    linux,
    macos,
    windows,
  ];
  // Platforms that binary-only packages will NOT be assigned to.
  static final binaryOnlyNotAssignedPlatforms = recognizedPlatforms
      .where((e) => !binaryOnlyAssignedPlatforms.contains(e))
      .toList();

  static final android = Platform(
    'Android',
    dartRuntime: Runtime.nativeAot,
    flutterRuntime: Runtime.flutterNative,
    tag: PanaTags.platformAndroid,
  );
  static final ios = Platform(
    'iOS',
    dartRuntime: null,
    flutterRuntime: Runtime.flutterNative,
    tag: PanaTags.platformIos,
  );
  static final linux = Platform(
    'Linux',
    dartRuntime: Runtime.nativeJit,
    flutterRuntime: Runtime.flutterNative,
    tag: PanaTags.platformLinux,
  );
  static final macos = Platform(
    'macOS',
    dartRuntime: Runtime.nativeJit,
    flutterRuntime: Runtime.flutterNative,
    tag: PanaTags.platformMacos,
  );
  static final web = Platform(
    'Web',
    dartRuntime: Runtime.web,
    flutterRuntime: Runtime.flutterWeb,
    tag: PanaTags.platformWeb,
  );
  static final windows = Platform(
    'Windows',
    dartRuntime: Runtime.nativeJit,
    flutterRuntime: Runtime.flutterNative,
    tag: PanaTags.platformWindows,
  );

  @override
  String toString() => 'Platform($name)';
}

class Sdk {
  final String name;
  final String formattedName;
  final List<String> allowedSdks;
  final Runtime allowedRuntime;
  final String tag;
  Sdk(
    this.name,
    this.formattedName,
    this.allowedSdks,
    this.allowedRuntime, {
    required this.tag,
  });

  static Sdk dart = Sdk(
    'dart',
    'Dart',
    ['dart'],
    Runtime.broadDart,
    tag: PanaTags.sdkDart,
  );

  static Sdk flutter = Sdk(
    'flutter',
    'Flutter',
    ['dart', 'flutter'],
    Runtime.broadFlutter,
    tag: PanaTags.sdkFlutter,
  );

  static List<Sdk> knownSdks = [dart, flutter];
}
