// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.platform;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

DartPlatform _$DartPlatformFromJson(Map<String, dynamic> json) =>
    new DartPlatform(
        (json['components'] as List)?.map((e) => e as String)?.toList(),
        json['uses'] == null
            ? null
            : new Map<String, PlatformUse>.fromIterables(
                (json['uses'] as Map<String, dynamic>).keys,
                (json['uses'] as Map).values.map((e) => e == null
                    ? null
                    : PlatformUse.values.singleWhere(
                        (x) => x.toString() == "PlatformUse.${e}"))),
        reason: json['reason'] as String);

abstract class _$DartPlatformSerializerMixin {
  List<String> get components;
  Map<String, PlatformUse> get uses;
  String get reason;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('components', components);
    writeNotNull(
        'uses',
        uses == null
            ? null
            : new Map<String, dynamic>.fromIterables(
                uses.keys,
                uses.values.map(
                    (e) => e == null ? null : e.toString().split('.')[1])));
    writeNotNull('reason', reason);
    return val;
  }
}
