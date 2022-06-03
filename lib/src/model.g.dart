// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProcessedScreenshot _$ProcessedScreenshotFromJson(Map<String, dynamic> json) =>
    ProcessedScreenshot(
      json['originalImage'] as String,
      json['description'] as String,
      webpImage: json['webpImage'] as String,
      webpThumbnail: json['webpThumbnail'] as String,
      pngThumbnail: json['pngThumbnail'] as String,
    );

Map<String, dynamic> _$ProcessedScreenshotToJson(
        ProcessedScreenshot instance) =>
    <String, dynamic>{
      'originalImage': instance.originalImage,
      'webpImage': instance.webpImage,
      'webpThumbnail': instance.webpThumbnail,
      'pngThumbnail': instance.pngThumbnail,
      'description': instance.description,
    };

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
      licenses: (json['licenses'] as List<dynamic>?)
          ?.map((e) => License.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      report: json['report'] == null
          ? null
          : Report.fromJson(json['report'] as Map<String, dynamic>),
      references: json['references'] == null
          ? null
          : References.fromJson(json['references'] as Map<String, dynamic>),
      repository: json['repository'] == null
          ? null
          : Repository.fromJson(json['repository'] as Map<String, dynamic>),
      urlProblems: (json['urlProblems'] as List<dynamic>?)
          ?.map((e) => UrlProblem.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      screenshots: (json['screenshots'] as List<dynamic>?)
          ?.map((e) => ProcessedScreenshot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SummaryToJson(Summary instance) {
  final val = <String, dynamic>{
    'runtimeInfo': instance.runtimeInfo.toJson(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

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
  writeNotNull('references', instance.references?.toJson());
  writeNotNull('repository', instance.repository?.toJson());
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
      'status': _$ReportStatusEnumMap[instance.status],
      'summary': instance.summary,
    };

const _$ReportStatusEnumMap = {
  ReportStatus.failed: 'failed',
  ReportStatus.partial: 'partial',
  ReportStatus.passed: 'passed',
};

References _$ReferencesFromJson(Map<String, dynamic> json) => References(
      homepageUrl: json['homepageUrl'] as String?,
      repositoryUrl: json['repositoryUrl'] as String?,
      issueTrackerUrl: json['issueTrackerUrl'] as String?,
      documentationUrl: json['documentationUrl'] as String?,
    );

Map<String, dynamic> _$ReferencesToJson(References instance) {
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
  return val;
}

Repository _$RepositoryFromJson(Map<String, dynamic> json) => Repository(
      baseUrl: json['baseUrl'] as String,
      branch: json['branch'] as String?,
      packagePath: json['packagePath'] as String?,
      isVerified: json['isVerified'] as bool?,
      verificationFailure: json['verificationFailure'] as String?,
    );

Map<String, dynamic> _$RepositoryToJson(Repository instance) {
  final val = <String, dynamic>{
    'baseUrl': instance.baseUrl,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('branch', instance.branch);
  writeNotNull('packagePath', instance.packagePath);
  writeNotNull('isVerified', instance.isVerified);
  writeNotNull('verificationFailure', instance.verificationFailure);
  return val;
}

UrlProblem _$UrlProblemFromJson(Map<String, dynamic> json) => UrlProblem(
      url: json['url'] as String,
      problem: json['problem'] as String,
    );

Map<String, dynamic> _$UrlProblemToJson(UrlProblem instance) =>
    <String, dynamic>{
      'url': instance.url,
      'problem': instance.problem,
    };
