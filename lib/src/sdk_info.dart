// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pub_semver/pub_semver.dart';

class DartSdkInfo {
  static final _sdkRegexp =
      new RegExp('Dart VM version:\\s([^\\s]+)\\s\\(([^\\)]+)\\) on "(\\w+)"');

  // TODO: parse an actual `DateTime` here. Likely requires using pkg/intl
  final String dateString;
  final String platform;
  final Version version;

  DartSdkInfo._(this.version, this.dateString, this.platform);

  factory DartSdkInfo.parse(String versionOutput) {
    var match = _sdkRegexp.firstMatch(versionOutput);
    var version = new Version.parse(match[1]);
    var dateString = match[2];
    var platform = match[3];

    return new DartSdkInfo._(version, dateString, platform);
  }
}
