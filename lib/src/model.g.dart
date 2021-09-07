// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Summary _$SummaryFromJson(Map<String, dynamic> json) => Summary(
      runtimeInfo:
          PanaRuntimeInfo.fromJson(json['runtimeInfo'] as Map<String, dynamic>),
      packageName: json['packageName'] as String?,
      packageVersion:
          const VersionConverter().fromJson(json['packageVersion'] as String?),
      pubspec: json['pubspec'] == null
          ? null
          : Pubspec.fromJson(json['pubspec'] as Map<String, dynamic>),
      allDependencies: (json['allDependencies'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      licenseFile: json['licenseFile'] == null
          ? null
          : LicenseFile.fromJson(json['licenseFile'] as Map<String, dynamic>),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      report: json['report'] == null
          ? null
          : Report.fromJson(json['report'] as Map<String, dynamic>),
      urlProblems: (json['urlProblems'] as List<dynamic>?)
          ?.map((e) => UrlProblem.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$SummaryToJson(Summary instance) {
  final val = <String, dynamic>{
    'runtimeInfo': instance.runtimeInfo,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('packageName', instance.packageName);
  writeNotNull('packageVersion',
      const VersionConverter().toJson(instance.packageVersion));
  writeNotNull('pubspec', instance.pubspec);
  writeNotNull('licenseFile', instance.licenseFile);
  writeNotNull('allDependencies', instance.allDependencies);
  writeNotNull('tags', instance.tags);
  writeNotNull('report', instance.report);
  writeNotNull('urlProblems', instance.urlProblems);
  writeNotNull('errorMessage', instance.errorMessage);
  return val;
}

PanaRuntimeInfo _$PanaRuntimeInfoFromJson(Map<String, dynamic> json) =>
    PanaRuntimeInfo(
      panaVersion: json['panaVersion'] as String,
      sdkVersion: json['sdkVersion'] as String,
      flutterVersions: json['flutterVersions'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$PanaRuntimeInfoToJson(PanaRuntimeInfo instance) {
  final val = <String, dynamic>{
    'panaVersion': instance.panaVersion,
    'sdkVersion': instance.sdkVersion,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('flutterVersions', instance.flutterVersions);
  return val;
}

LicenseFile _$LicenseFileFromJson(Map<String, dynamic> json) => LicenseFile(
      json['path'] as String,
      json['name'] as String,
      version: json['version'] as String?,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$LicenseFileToJson(LicenseFile instance) {
  final val = <String, dynamic>{
    'path': instance.path,
    'name': instance.name,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('version', instance.version);
  writeNotNull('url', instance.url);
  return val;
}

Report _$ReportFromJson(Map<String, dynamic> json) => Report(
      sections: (json['sections'] as List<dynamic>)
          .map((e) => ReportSection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ReportToJson(Report instance) => <String, dynamic>{
      'sections': instance.sections.map((e) => e.toJson()).toList(),
    };

ReportSection _$ReportSectionFromJson(Map<String, dynamic> json) =>
    ReportSection(
      id: json['id'] as String,
      title: json['title'] as String,
      grantedPoints: json['grantedPoints'] as int,
      maxPoints: json['maxPoints'] as int,
      summary: json['summary'] as String,
      status: _$enumDecode(_$ReportStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$ReportSectionToJson(ReportSection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'grantedPoints': instance.grantedPoints,
      'maxPoints': instance.maxPoints,
      'status': _$ReportStatusEnumMap[instance.status],
      'summary': instance.summary,
    };

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

const _$ReportStatusEnumMap = {
  ReportStatus.failed: 'failed',
  ReportStatus.partial: 'partial',
  ReportStatus.passed: 'passed',
};

UrlProblem _$UrlProblemFromJson(Map<String, dynamic> json) => UrlProblem(
      url: json['url'] as String,
      problem: json['problem'] as String,
    );

Map<String, dynamic> _$UrlProblemToJson(UrlProblem instance) =>
    <String, dynamic>{
      'url': instance.url,
      'problem': instance.problem,
    };
