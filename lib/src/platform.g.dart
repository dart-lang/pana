// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.platform;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

PlatformStatus _$PlatformStatusFromJson(Map<String, dynamic> json) =>
    new PlatformStatus(json['name'] as String, json['isAllowed'] as bool,
        json['isUsed'] as bool);

abstract class _$PlatformStatusSerializerMixin {
  String get name;
  bool get isAllowed;
  bool get isUsed;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'name': name, 'isAllowed': isAllowed, 'isUsed': isUsed};
}

DartPlatform _$DartPlatformFromJson(Map<String, dynamic> json) =>
    new DartPlatform(
        json['worksEverywhere'] as bool,
        (json['restrictedTo'] as List)?.map((e) => e as String)?.toList(),
        json['reason'] as String);

abstract class _$DartPlatformSerializerMixin {
  bool get worksEverywhere;
  List<String> get restrictedTo;
  String get reason;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'worksEverywhere': worksEverywhere,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('restrictedTo', restrictedTo);
    writeNotNull('reason', reason);
    return val;
  }
}
