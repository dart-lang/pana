// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'internal_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Outdated _$OutdatedFromJson(Map<String, dynamic> json) {
  return Outdated(
    (json['packages'] as List<dynamic>)
        .map((e) => OutdatedPackage.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$OutdatedToJson(Outdated instance) => <String, dynamic>{
      'packages': instance.packages,
    };

OutdatedPackage _$OutdatedPackageFromJson(Map<String, dynamic> json) {
  return OutdatedPackage(
    json['package'] as String,
    json['upgradable'] == null
        ? null
        : VersionDescriptor.fromJson(
            json['upgradable'] as Map<String, dynamic>),
    json['latest'] == null
        ? null
        : VersionDescriptor.fromJson(json['latest'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$OutdatedPackageToJson(OutdatedPackage instance) =>
    <String, dynamic>{
      'package': instance.package,
      'upgradable': instance.upgradable,
      'latest': instance.latest,
    };

VersionDescriptor _$VersionDescriptorFromJson(Map<String, dynamic> json) {
  return VersionDescriptor(
    json['version'] as String,
  );
}

Map<String, dynamic> _$VersionDescriptorToJson(VersionDescriptor instance) =>
    <String, dynamic>{
      'version': instance.version,
    };
