// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.platform;

// **************************************************************************
// Generator: JsonSerializableGenerator
// Target: class PlatformSummary
// **************************************************************************

PlatformSummary _$PlatformSummaryFromJson(Map json) => new PlatformSummary(
    json['package'] == null ? null : new PlatformInfo.fromJson(json['package']),
    json['libraries'] as Map<String, PlatformInfo>);

abstract class _$PlatformSummarySerializerMixin {
  PlatformInfo get package;
  Map<String, PlatformInfo> get libraries;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'package': package, 'libraries': libraries};
}

// **************************************************************************
// Generator: JsonSerializableGenerator
// Target: class PlatformInfo
// **************************************************************************

PlatformInfo _$PlatformInfoFromJson(Map json) =>
    new PlatformInfo((json['uses'] as List)?.map((v0) => v0 as String));

abstract class _$PlatformInfoSerializerMixin {
  List<String> get uses;
  Map<String, dynamic> toJson() => <String, dynamic>{'uses': uses};
}
