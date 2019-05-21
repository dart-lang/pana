// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

class VersionConverter implements JsonConverter<Version, String> {
  const VersionConverter();

  @override
  Version fromJson(String json) => json == null ? null : Version.parse(json);

  @override
  String toJson(Version object) => object?.toString();
}

class VersionConstraintConverter
    implements JsonConverter<VersionConstraint, String> {
  const VersionConstraintConverter();

  @override
  VersionConstraint fromJson(String json) =>
      json == null ? null : VersionConstraint.parse(json);

  @override
  String toJson(VersionConstraint object) => object?.toString();
}
