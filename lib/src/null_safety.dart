// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.12

import 'package:pub_semver/pub_semver.dart';

final _firstVersionWithNullSafety = Version.parse('2.12.0');

// TODO: remove [packageName] in a future breaking release.
bool isNullSafety(Version version, [String? packageName]) =>
    Version(version.major, version.minor, 0) >= _firstVersionWithNullSafety;
