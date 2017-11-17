// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

Matcher isSemVer = predicate<String>((String versionString) {
  try {
    new Version.parse(versionString);
  } catch (e) {
    return false;
  }
  return true;
}, 'can be parsed as a version');

class E2EData {
  final String name;
  final String version;
  final Map<String, dynamic> data;

  E2EData(this.name, this.version, this.data);
}
