// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.health;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

Fitness _$FitnessFromJson(Map<String, dynamic> json) => new Fitness(
    (json['magnitude'] as num)?.toDouble(),
    (json['shortcoming'] as num)?.toDouble(),
    suggestions: (json['suggestions'] as List)
        ?.map((e) => e == null
            ? null
            : new Suggestion.fromJson(e as Map<String, dynamic>))
        ?.toList());

abstract class _$FitnessSerializerMixin {
  double get magnitude;
  double get shortcoming;
  List<Suggestion> get suggestions;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'magnitude': magnitude,
      'shortcoming': shortcoming,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('suggestions', suggestions);
    return val;
  }
}
