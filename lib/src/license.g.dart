// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.license;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

LicenseFile _$LicenseFileFromJson(Map<String, dynamic> json) =>
    new LicenseFile(json['path'] as String, json['name'] as String,
        version: json['version'] as String, url: json['url'] as String);

abstract class _$LicenseFileSerializerMixin {
  String get path;
  String get name;
  String get version;
  String get url;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'path': path,
      'name': name,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('version', version);
    writeNotNull('url', url);
    return val;
  }
}
