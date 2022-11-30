// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProcessedScreenshot _$ProcessedScreenshotFromJson(Map<String, dynamic> json) =>
    ProcessedScreenshot(
      json['originalImage'] as String,
      json['description'] as String,
      webpImage: json['webpImage'] as String,
      webp100Thumbnail: json['webp100Thumbnail'] as String,
      png100Thumbnail: json['png100Thumbnail'] as String,
      webp190Thumbnail: json['webp190Thumbnail'] as String,
      png190Thumbnail: json['png190Thumbnail'] as String,
    );

Map<String, dynamic> _$ProcessedScreenshotToJson(
        ProcessedScreenshot instance) =>
    <String, dynamic>{
      'originalImage': instance.originalImage,
      'webpImage': instance.webpImage,
      'webp100Thumbnail': instance.webp100Thumbnail,
      'png100Thumbnail': instance.png100Thumbnail,
      'webp190Thumbnail': instance.webp190Thumbnail,
      'png190Thumbnail': instance.png190Thumbnail,
      'description': instance.description,
    };

Summary _$SummaryFromJson(Map<String, dynamic> json) => Summary(
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
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
      licenses: (json['licenses'] as List<dynamic>?)
          ?.map((e) => License.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      report: json['report'] == null
          ? null
          : Report.fromJson(json['report'] as Map<String, dynamic>),
      result: json['result'] == null
          ? null
          : AnalysisResult.fromJson(json['result'] as Map<String, dynamic>),
      urlProblems: (json['urlProblems'] as List<dynamic>?)
          ?.map((e) => UrlProblem.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      screenshots: (json['screenshots'] as List<dynamic>?)
          ?.map((e) => ProcessedScreenshot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SummaryToJson(Summary instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('createdAt', instance.createdAt?.toIso8601String());
  val['runtimeInfo'] = instance.runtimeInfo.toJson();
  writeNotNull('packageName', instance.packageName);
  writeNotNull('packageVersion',
      const VersionConverter().toJson(instance.packageVersion));
  writeNotNull('pubspec', instance.pubspec?.toJson());
  writeNotNull('licenseFile', instance.licenseFile?.toJson());
  writeNotNull('licenses', instance.licenses?.map((e) => e.toJson()).toList());
  writeNotNull('allDependencies', instance.allDependencies);
  writeNotNull('tags', instance.tags);
  writeNotNull('report', instance.report?.toJson());
  writeNotNull(
      'screenshots', instance.screenshots?.map((e) => e.toJson()).toList());
  writeNotNull('result', instance.result?.toJson());
  writeNotNull(
      'urlProblems', instance.urlProblems?.map((e) => e.toJson()).toList());
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

License _$LicenseFromJson(Map<String, dynamic> json) => License(
      path: json['path'] as String,
      spdxIdentifier: json['spdxIdentifier'] as String,
    );

Map<String, dynamic> _$LicenseToJson(License instance) => <String, dynamic>{
      'path': instance.path,
      'spdxIdentifier': instance.spdxIdentifier,
    };

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
      status: $enumDecode(_$ReportStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$ReportSectionToJson(ReportSection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'grantedPoints': instance.grantedPoints,
      'maxPoints': instance.maxPoints,
      'status': _$ReportStatusEnumMap[instance.status]!,
      'summary': instance.summary,
    };

const _$ReportStatusEnumMap = {
  ReportStatus.failed: 'failed',
  ReportStatus.partial: 'partial',
  ReportStatus.passed: 'passed',
};

AnalysisResult _$AnalysisResultFromJson(Map<String, dynamic> json) =>
    AnalysisResult(
      homepageUrl: json['homepageUrl'] as String?,
      repositoryUrl: json['repositoryUrl'] as String?,
      issueTrackerUrl: json['issueTrackerUrl'] as String?,
      documentationUrl: json['documentationUrl'] as String?,
      fundingUrls: (json['fundingUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      repository: json['repository'] == null
          ? null
          : Repository.fromJson(json['repository'] as Map<String, dynamic>),
      contributingUrl: json['contributingUrl'] as String?,
    );

Map<String, dynamic> _$AnalysisResultToJson(AnalysisResult instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('homepageUrl', instance.homepageUrl);
  writeNotNull('repositoryUrl', instance.repositoryUrl);
  writeNotNull('issueTrackerUrl', instance.issueTrackerUrl);
  writeNotNull('documentationUrl', instance.documentationUrl);
  writeNotNull('fundingUrls', instance.fundingUrls);
  writeNotNull('repository', instance.repository?.toJson());
  writeNotNull('contributingUrl', instance.contributingUrl);
  return val;
}

Repository _$RepositoryFromJson(Map<String, dynamic> json) => Repository(
      provider:
          $enumDecodeNullable(_$RepositoryProviderEnumMap, json['provider']),
      host: json['host'] as String,
      repository: json['repository'] as String?,
      branch: json['branch'] as String?,
      path: json['path'] as String?,
    );

Map<String, dynamic> _$RepositoryToJson(Repository instance) {
  final val = <String, dynamic>{
    'provider': _$RepositoryProviderEnumMap[instance.provider]!,
    'host': instance.host,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('repository', instance.repository);
  writeNotNull('branch', instance.branch);
  writeNotNull('path', instance.path);
  return val;
}

const _$RepositoryProviderEnumMap = {
  RepositoryProvider.github: 'github',
  RepositoryProvider.gitlab: 'gitlab',
  RepositoryProvider.unknown: 'unknown',
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
