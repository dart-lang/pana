// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.platform;

// **************************************************************************
// Generator: JsonSerializableGenerator
// Target: class Platform
// **************************************************************************

Platform _$PlatformFromJson(Map json) =>
    new Platform((json['uses'] as List)?.map((v0) => v0 as String));

abstract class _$PlatformSerializerMixin {
  List get uses;
  Map<String, dynamic> toJson() => <String, dynamic>{'uses': uses};
}
