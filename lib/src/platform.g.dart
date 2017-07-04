// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.platform;

// **************************************************************************
// Generator: JsonSerializableGenerator
// Target: class Platform
// **************************************************************************

PlatformInfo _$PlatformFromJson(Map json) =>
    new PlatformInfo((json['uses'] as List)?.map((v0) => v0 as String));

abstract class _$PlatformInfoSerializerMixin {
  List<String> get uses;
  Map<String, dynamic> toJson() => <String, dynamic>{'uses': uses};
}
