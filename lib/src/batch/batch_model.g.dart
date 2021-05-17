// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BatchConfig _$BatchConfigFromJson(Map<String, dynamic> json) {
  return BatchConfig(
    dartSdk: json['dartSdk'] as String,
    flutterSdk: json['flutterSdk'] as String,
    environment: (json['environment'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k, e as String),
    ),
    analysisOptions: json['analysisOptions'] as String,
  );
}

Map<String, dynamic> _$BatchConfigToJson(BatchConfig instance) =>
    <String, dynamic>{
      'dartSdk': instance.dartSdk,
      'flutterSdk': instance.flutterSdk,
      'environment': instance.environment,
      'analysisOptions': instance.analysisOptions,
    };

BatchResult _$BatchResultFromJson(Map<String, dynamic> json) {
  return BatchResult(
    unchangedCount: json['unchangedCount'] as int,
    increased: json['increased'] == null
        ? null
        : BatchChanged.fromJson(json['increased'] as Map<String, dynamic>),
    decreased: json['decreased'] == null
        ? null
        : BatchChanged.fromJson(json['decreased'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$BatchResultToJson(BatchResult instance) =>
    <String, dynamic>{
      'unchangedCount': instance.unchangedCount,
      'increased': instance.increased,
      'decreased': instance.decreased,
    };

BatchChanged _$BatchChangedFromJson(Map<String, dynamic> json) {
  return BatchChanged(
    count: json['count'] as int,
    packages: (json['packages'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k, e as int),
    ),
  );
}

Map<String, dynamic> _$BatchChangedToJson(BatchChanged instance) =>
    <String, dynamic>{
      'count': instance.count,
      'packages': instance.packages,
    };
