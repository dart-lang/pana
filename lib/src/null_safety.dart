// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pub_semver/pub_semver.dart';

bool isNullSafety(Version version, String packageName) =>
    Version(version.major, version.minor, 0) >=
    (packageName == null || _allowedExperimentPackages.contains(packageName)
        ? _firstVersionWithNullSafetyAllowedExperiment
        : _firstVersionWithNullSafety);

/// Packages that are allowed to opt-in to null-safety already from 2.10.
///
/// List extracted from:
/// https://github.com/dart-lang/sdk/blob/master/sdk/lib/_internal/allowed_experiments.json
final _allowedExperimentPackages = {
  'async',
  'boolean_selector',
  'characters',
  'charcode',
  'clock',
  'collection',
  'connectivity',
  'connectivity_platform_interface',
  'convert',
  'crypto',
  'csslib',
  'dart_internal',
  'device_info',
  'device_info_platform_interface',
  'fake_async',
  'file',
  'fixnum',
  'flutter',
  'flutter_driver',
  'flutter_test',
  'flutter_goldens',
  'flutter_goldens_client',
  'http',
  'http_parser',
  'intl',
  'js',
  'logging',
  'matcher',
  'meta',
  'native_stack_traces',
  'observatory',
  'observatory_test_package',
  'path',
  'pedantic',
  'platform',
  'plugin_platform_interface',
  'pool',
  'process',
  'pub_semver',
  'sky_engine',
  'source_maps',
  'source_map_stack_trace',
  'source_span',
  'stack_trace',
  'stream_channel',
  'string_scanner',
  'term_glyph',
  'test',
  'test_api',
  'test_core',
  'typed_data',
  'url_launcher',
  'url_launcher_linux',
  'url_launcher_macos',
  'url_launcher_platform_interface',
  'url_launcher_windows',
  'vector_math',
  'video_player',
  'video_player_platform_interface',
  'video_player_web',
};
final _firstVersionWithNullSafety = Version.parse('2.12.0');
final _firstVersionWithNullSafetyAllowedExperiment = Version.parse('2.10.0');
