// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BatchConfig _$BatchConfigFromJson(Map<String, dynamic> json) => BatchConfig(
      dartSdk: json['dartSdk'] as String?,
      flutterSdk: json['flutterSdk'] as String?,
      environment: (json['environment'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      analysisOptions: json['analysisOptions'] as String?,
    );

Map<String, dynamic> _$BatchConfigToJson(BatchConfig instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('dartSdk', instance.dartSdk);
  writeNotNull('flutterSdk', instance.flutterSdk);
  writeNotNull('environment', instance.environment);
  writeNotNull('analysisOptions', instance.analysisOptions);
  return val;
}

BatchResult _$BatchResultFromJson(Map<String, dynamic> json) => BatchResult(
      unchangedCount: json['unchangedCount'] as int,
      increased:
          BatchChanged.fromJson(json['increased'] as Map<String, dynamic>),
      decreased:
          BatchChanged.fromJson(json['decreased'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BatchResultToJson(BatchResult instance) =>
    <String, dynamic>{
      'unchangedCount': instance.unchangedCount,
      'increased': instance.increased.toJson(),
      'decreased': instance.decreased.toJson(),
    };

BatchChanged _$BatchChangedFromJson(Map<String, dynamic> json) => BatchChanged(
      count: json['count'] as int,
      packages: Map<String, int>.from(json['packages'] as Map),
    );

Map<String, dynamic> _$BatchChangedToJson(BatchChanged instance) =>
    <String, dynamic>{
      'count': instance.count,
      'packages': instance.packages,
    };
