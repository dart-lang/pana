// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'internal_model.g.dart';

/// The json output from `dart pub outdated --json`.
@JsonSerializable()
class Outdated {
  final List<OutdatedPackage> packages;

  Outdated(this.packages);

  static Outdated fromJson(Map<String, dynamic> json) =>
      _$OutdatedFromJson(json);

  Map<String, dynamic> toJson() => _$OutdatedToJson(this);
}

@JsonSerializable()
class OutdatedPackage {
  final String package;
  final VersionDescriptor? upgradable;
  final VersionDescriptor? latest;

  OutdatedPackage(this.package, this.upgradable, this.latest);

  static OutdatedPackage fromJson(Map<String, dynamic> json) =>
      _$OutdatedPackageFromJson(json);

  Map<String, dynamic> toJson() => _$OutdatedPackageToJson(this);
}

@JsonSerializable()
class VersionDescriptor {
  final String version;

  VersionDescriptor(this.version);

  static VersionDescriptor fromJson(Map<String, dynamic> json) =>
      _$VersionDescriptorFromJson(json);

  Map<String, dynamic> toJson() => _$VersionDescriptorToJson(this);
}
