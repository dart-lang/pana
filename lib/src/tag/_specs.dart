// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Represents a dart runtime and the `dart:` libraries available on that
/// platform.
class Runtime {
  final String name;
  final Set<String> enabledLibs;
  final String? _tag;

  Runtime(this.name, this.enabledLibs, {String? tag}) : _tag = tag;

  Map<String, String> get declaredVariables =>
      {for (final lib in enabledLibs) 'dart.library.$lib': 'true'};

  @override
  String toString() => 'Runtime($name)';

  String get tag => _tag ?? 'runtime:$name';

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

  static final nativeJit = Runtime(
      'vm-native',
      {
        ..._onAllPlatforms,
        ..._onAllNative,
        'cli',
        'developer',
        'mirrors',
        'nativewrappers',
      },
      tag: 'runtime:native-jit');

  static final recognizedRuntimes = [
    nativeAot,
    nativeJit,
    web,
  ];

  static final nativeAot = Runtime('native-aot', {
    ..._onAllPlatforms,
    ..._onAllNative,
    'cli',
    'nativewrappers',
  });

  static final web = Runtime(
      'js',
      {
        ..._onAllPlatforms,
        ..._onAllWeb,
        'html_common',
      },
      tag: 'runtime:web');

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

  /// For platform detection we allow dart:ui.
  static final broadWeb = Runtime('web', {
    ..._onAllPlatforms,
    ..._onAllWeb,
    'ui',
  });

  /// For platform detection we allow dart:ui.
  static final broadNative = Runtime('native', {
    ..._onAllPlatforms,
    ..._onAllNative,
    'ui',
  });
}

/// A platform where Dart and Flutter can be deployed.
class Platform {
  final String name;
  final Runtime runtime;
  final String tag;

  Platform(this.name, this.runtime, {required this.tag});

  static final List<Platform> recognizedPlatforms = [
    android,
    ios,
    Platform('Windows', Runtime.broadNative, tag: 'platform:windows'),
    Platform('Linux', Runtime.broadNative, tag: 'platform:linux'),
    Platform('macOS', Runtime.broadNative, tag: 'platform:macos'),
    Platform('Web', Runtime.broadWeb, tag: 'platform:web'),
  ];

  static final android = Platform(
    'Android',
    Runtime.broadNative,
    tag: 'platform:android',
  );
  static final ios = Platform('iOS', Runtime.broadNative, tag: 'platform:ios');

  @override
  String toString() => 'FlutterPlatform($name)';
}

class Sdk {
  final String name;
  final String formattedName;
  final List<String> allowedSdks;
  final List<Runtime> allowedRuntimes;
  Sdk(this.name, this.formattedName, this.allowedSdks, this.allowedRuntimes);

  String get tag => 'sdk:$name';

  static Sdk dart = Sdk('dart', 'Dart', ['dart'],
      [Runtime.nativeAot, Runtime.nativeJit, Runtime.web]);

  static Sdk flutter = Sdk('flutter', 'Flutter', ['dart', 'flutter'],
      [Runtime.flutterNative, Runtime.flutterWeb]);

  static List<Sdk> knownSdks = [dart, flutter];
}
