// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The tags that pana may assign to an analyzed package.
abstract class PanaTags {
  // sdk tags
  static const sdkDart = 'sdk:dart';
  static const sdkFlutter = 'sdk:flutter';

  // runtime tags
  static const runtimeDart = 'runtime:dart';
  static const runtimeNative = 'runtime:native';
  static const runtimeNativeAot = 'runtime:native-aot';
  static const runtimeNativeJit = 'runtime:native-jit';
  static const runtimeFlutter = 'runtime:flutter';
  static const runtimeFlutterNative = 'runtime:flutter-native';
  static const runtimeFlutterWeb = 'runtime:flutter-web';
  static const runtimeWeb = 'runtime:web';

  // platform tags
  static const platformAndroid = 'platform:android';
  static const platformIos = 'platform:ios';
  static const platformLinux = 'platform:linux';
  static const platformMacos = 'platform:macos';
  static const platformWeb = 'platform:web';
  static const platformWindows = 'platform:windows';

  // license tags
  static const licenceFsfLibre = 'license:fsf-libre';
  static const licenseOsiApproved = 'license:osi-approved';
  static const licenseUnknown = 'license:unknown';

  // others
  static const hasError = 'has:error';
  static const hasScreenshot = 'has:screenshot';
  static const isPlugin = 'is:plugin';
  static const isNullSafe = 'is:null-safe';

  /// Given a [topic] returns the `topic` tag assigned to an analyzed package.
  static String topic(String topic) => 'topic:$topic';
}
