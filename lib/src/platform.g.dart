// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.platform;

// **************************************************************************
// Generator: JsonSerializableGenerator
// Target: class PlatformSummary
// **************************************************************************

PlatformSummary _$PlatformSummaryFromJson(Map<String, dynamic> json) =>
    new PlatformSummary(
        json['pubspec'] == null
            ? null
            : new PubspecPlatform.fromJson(json['pubspec'] as String),
        json['libraries'] == null
            ? null
            : new Map<String, PlatformInfo>.fromIterables(
                (json['libraries'] as Map<String, dynamic>).keys,
                (json['libraries'] as Map).values.map((e) => e == null
                    ? null
                    : new PlatformInfo.fromJson(e as Map<String, dynamic>))));

abstract class _$PlatformSummarySerializerMixin {
  PubspecPlatform get pubspec;
  Map<String, PlatformInfo> get libraries;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'pubspec': pubspec,
        'libraries': libraries == null
            ? null
            : new Map<String, dynamic>.fromIterables(
                libraries.keys, libraries.values.map((e) => e))
      };
}

// **************************************************************************
// Generator: JsonSerializableGenerator
// Target: class PlatformInfo
// **************************************************************************

PlatformInfo _$PlatformInfoFromJson(Map<String, dynamic> json) =>
    new PlatformInfo((json['uses'] as List)?.map((e) => e as String));

abstract class _$PlatformInfoSerializerMixin {
  List<String> get uses;
  Map<String, dynamic> toJson() => <String, dynamic>{'uses': uses};
}
