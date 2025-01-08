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

Map<String, dynamic> _$SummaryToJson(Summary instance) => <String, dynamic>{
      if (instance.createdAt?.toIso8601String() case final value?)
        'createdAt': value,
      'runtimeInfo': instance.runtimeInfo.toJson(),
      if (instance.packageName case final value?) 'packageName': value,
      if (const VersionConverter().toJson(instance.packageVersion)
          case final value?)
        'packageVersion': value,
      if (instance.pubspec?.toJson() case final value?) 'pubspec': value,
      if (instance.licenseFile?.toJson() case final value?)
        'licenseFile': value,
      if (instance.licenses?.map((e) => e.toJson()).toList() case final value?)
        'licenses': value,
      if (instance.allDependencies case final value?) 'allDependencies': value,
      if (instance.tags case final value?) 'tags': value,
      if (instance.report?.toJson() case final value?) 'report': value,
      if (instance.screenshots?.map((e) => e.toJson()).toList()
          case final value?)
        'screenshots': value,
      if (instance.result?.toJson() case final value?) 'result': value,
      if (instance.urlProblems?.map((e) => e.toJson()).toList()
          case final value?)
        'urlProblems': value,
      if (instance.errorMessage case final value?) 'errorMessage': value,
    };

PanaRuntimeInfo _$PanaRuntimeInfoFromJson(Map<String, dynamic> json) =>
    PanaRuntimeInfo(
      panaVersion: json['panaVersion'] as String,
      sdkVersion: json['sdkVersion'] as String,
      flutterVersions: json['flutterVersions'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$PanaRuntimeInfoToJson(PanaRuntimeInfo instance) =>
    <String, dynamic>{
      'panaVersion': instance.panaVersion,
      'sdkVersion': instance.sdkVersion,
      if (instance.flutterVersions case final value?) 'flutterVersions': value,
    };

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
    );

Map<String, dynamic> _$LicenseFileToJson(LicenseFile instance) =>
    <String, dynamic>{
      'path': instance.path,
      'name': instance.name,
      if (instance.version case final value?) 'version': value,
    };

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
      grantedPoints: (json['grantedPoints'] as num).toInt(),
      maxPoints: (json['maxPoints'] as num).toInt(),
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
      repositoryStatus: $enumDecodeNullable(
          _$RepositoryStatusEnumMap, json['repositoryStatus']),
      repository: json['repository'] == null
          ? null
          : Repository.fromJson(json['repository'] as Map<String, dynamic>),
      contributingUrl: json['contributingUrl'] as String?,
      licenses: (json['licenses'] as List<dynamic>?)
          ?.map((e) => License.fromJson(e as Map<String, dynamic>))
          .toList(),
      grantedPoints: (json['grantedPoints'] as num?)?.toInt(),
      maxPoints: (json['maxPoints'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AnalysisResultToJson(AnalysisResult instance) =>
    <String, dynamic>{
      if (instance.homepageUrl case final value?) 'homepageUrl': value,
      if (instance.repositoryUrl case final value?) 'repositoryUrl': value,
      if (instance.issueTrackerUrl case final value?) 'issueTrackerUrl': value,
      if (instance.documentationUrl case final value?)
        'documentationUrl': value,
      if (instance.fundingUrls case final value?) 'fundingUrls': value,
      if (_$RepositoryStatusEnumMap[instance.repositoryStatus]
          case final value?)
        'repositoryStatus': value,
      if (instance.repository?.toJson() case final value?) 'repository': value,
      if (instance.contributingUrl case final value?) 'contributingUrl': value,
      if (instance.licenses?.map((e) => e.toJson()).toList() case final value?)
        'licenses': value,
      if (instance.grantedPoints case final value?) 'grantedPoints': value,
      if (instance.maxPoints case final value?) 'maxPoints': value,
    };

const _$RepositoryStatusEnumMap = {
  RepositoryStatus.unspecified: 'unspecified',
  RepositoryStatus.invalid: 'invalid',
  RepositoryStatus.missing: 'missing',
  RepositoryStatus.failed: 'failed',
  RepositoryStatus.verified: 'verified',
  RepositoryStatus.inconclusive: 'inconclusive',
};

Repository _$RepositoryFromJson(Map<String, dynamic> json) => Repository(
      provider:
          $enumDecodeNullable(_$RepositoryProviderEnumMap, json['provider']),
      host: json['host'] as String,
      repository: json['repository'] as String?,
      branch: json['branch'] as String?,
      path: json['path'] as String?,
    );

Map<String, dynamic> _$RepositoryToJson(Repository instance) =>
    <String, dynamic>{
      'provider': _$RepositoryProviderEnumMap[instance.provider]!,
      'host': instance.host,
      if (instance.repository case final value?) 'repository': value,
      if (instance.branch case final value?) 'branch': value,
      if (instance.path case final value?) 'path': value,
    };

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
