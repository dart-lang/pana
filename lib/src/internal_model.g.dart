// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'internal_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Outdated _$OutdatedFromJson(Map<String, dynamic> json) => Outdated(
      (json['packages'] as List<dynamic>)
          .map((e) => OutdatedPackage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OutdatedToJson(Outdated instance) => <String, dynamic>{
      'packages': instance.packages.map((e) => e.toJson()).toList(),
    };

OutdatedPackage _$OutdatedPackageFromJson(Map<String, dynamic> json) =>
    OutdatedPackage(
      json['package'] as String,
      json['upgradable'] == null
          ? null
          : VersionDescriptor.fromJson(
              json['upgradable'] as Map<String, dynamic>),
      json['latest'] == null
          ? null
          : VersionDescriptor.fromJson(json['latest'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OutdatedPackageToJson(OutdatedPackage instance) =>
    <String, dynamic>{
      'package': instance.package,
      if (instance.upgradable?.toJson() case final value?) 'upgradable': value,
      if (instance.latest?.toJson() case final value?) 'latest': value,
    };

VersionDescriptor _$VersionDescriptorFromJson(Map<String, dynamic> json) =>
    VersionDescriptor(
      json['version'] as String,
    );

Map<String, dynamic> _$VersionDescriptorToJson(VersionDescriptor instance) =>
    <String, dynamic>{
      'version': instance.version,
    };

CodeProblem _$CodeProblemFromJson(Map<String, dynamic> json) => CodeProblem(
      severity: json['severity'] as String,
      errorType: json['errorType'] as String,
      errorCode: json['errorCode'] as String,
      description: json['description'] as String,
      file: json['file'] as String,
      line: (json['line'] as num).toInt(),
      col: (json['col'] as num).toInt(),
      length: (json['length'] as num).toInt(),
    );

Map<String, dynamic> _$CodeProblemToJson(CodeProblem instance) =>
    <String, dynamic>{
      'severity': instance.severity,
      'errorType': instance.errorType,
      'errorCode': instance.errorCode,
      'file': instance.file,
      'line': instance.line,
      'col': instance.col,
      'length': instance.length,
      'description': instance.description,
    };

UrlStatus _$UrlStatusFromJson(Map<String, dynamic> json) => UrlStatus(
      isInvalid: json['isInvalid'] as bool,
      isSecure: json['isSecure'] as bool,
      exists: json['exists'] as bool,
    );

Map<String, dynamic> _$UrlStatusToJson(UrlStatus instance) => <String, dynamic>{
      'isInvalid': instance.isInvalid,
      'isSecure': instance.isSecure,
      'exists': instance.exists,
    };

VerifiedRepository _$VerifiedRepositoryFromJson(Map<String, dynamic> json) =>
    VerifiedRepository(
      status: $enumDecode(_$RepositoryStatusEnumMap, json['status']),
      repository: json['repository'] == null
          ? null
          : Repository.fromJson(json['repository'] as Map<String, dynamic>),
      contributingUrl: json['contributingUrl'] as String?,
      verificationFailure: json['verificationFailure'] as String?,
    );

Map<String, dynamic> _$VerifiedRepositoryToJson(VerifiedRepository instance) =>
    <String, dynamic>{
      'status': _$RepositoryStatusEnumMap[instance.status]!,
      if (instance.repository?.toJson() case final value?) 'repository': value,
      if (instance.contributingUrl case final value?) 'contributingUrl': value,
      if (instance.verificationFailure case final value?)
        'verificationFailure': value,
    };

const _$RepositoryStatusEnumMap = {
  RepositoryStatus.unspecified: 'unspecified',
  RepositoryStatus.invalid: 'invalid',
  RepositoryStatus.missing: 'missing',
  RepositoryStatus.failed: 'failed',
  RepositoryStatus.verified: 'verified',
  RepositoryStatus.inconclusive: 'inconclusive',
};
