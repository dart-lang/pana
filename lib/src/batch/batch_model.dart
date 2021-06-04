// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.12

import 'package:json_annotation/json_annotation.dart';

part 'batch_model.g.dart';

@JsonSerializable()
class BatchConfig {
  /// The path of the Dart SDK
  final String? dartSdk;

  /// The path of the Flutter SDK
  final String? flutterSdk;

  /// The environment variables that need to be set.
  final Map<String, String>? environment;

  /// The URI of the analysis options (https:// or local file).
  final String? analysisOptions;

  BatchConfig({
    this.dartSdk,
    this.flutterSdk,
    this.environment,
    this.analysisOptions,
  });

  factory BatchConfig.fromJson(Map<String, dynamic> json) =>
      _$BatchConfigFromJson(json);

  Map<String, dynamic> toJson() => _$BatchConfigToJson(this);
}

@JsonSerializable()
class BatchResult {
  final int unchangedCount;
  final BatchChanged increased;
  final BatchChanged decreased;

  BatchResult({
    required this.unchangedCount,
    required this.increased,
    required this.decreased,
  });

  factory BatchResult.fromJson(Map<String, dynamic> json) =>
      _$BatchResultFromJson(json);

  Map<String, dynamic> toJson() => _$BatchResultToJson(this);
}

@JsonSerializable()
class BatchChanged {
  final int count;
  final Map<String, int> packages;

  BatchChanged({
    required this.count,
    required this.packages,
  });

  factory BatchChanged.fromJson(Map<String, dynamic> json) =>
      _$BatchChangedFromJson(json);

  Map<String, dynamic> toJson() => _$BatchChangedToJson(this);
}
