// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'package:pana/src/sdk_env.dart';

void main() {
  test('parsing SDK version', () {
    final version =
        'Dart VM version: 2.0.0-dev.49.0 (Wed Apr 18 20:41:36 2018 +0200) on "macos_x64"';
    final sdkInfo = new DartSdkInfo.parse(version);
    expect(sdkInfo.version, new Version.parse('2.0.0-dev.49.0'));
  });
}
