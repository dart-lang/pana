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
  ProcessedScreenshot instance,
) => <String, dynamic>{
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
  runtimeInfo: PanaRuntimeInfo.fromJson(
    json['runtimeInfo'] as Map<String, dynamic>,
  ),
  packageName: json['packageName'] as String?,
  packageVersion: const VersionConverter().fromJson(
    json['packageVersion'] as String?,
  ),
  pubspec: json['pubspec'] == null
      ? null
      : Pubspec.fromJson(json['pubspec'] as Map<String, dynamic>),
  allDependencies: (json['allDependencies'] as List<dynamic>?)
      ?.map((e) => e as String)
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
  'createdAt': ?instance.createdAt?.toIso8601String(),
  'runtimeInfo': instance.runtimeInfo.toJson(),
  'packageName': ?instance.packageName,
  'packageVersion': ?const VersionConverter().toJson(instance.packageVersion),
  'pubspec': ?instance.pubspec?.toJson(),
  'allDependencies': ?instance.allDependencies,
  'tags': ?instance.tags,
  'report': ?instance.report?.toJson(),
  'screenshots': ?instance.screenshots?.map((e) => e.toJson()).toList(),
  'result': ?instance.result?.toJson(),
  'urlProblems': ?instance.urlProblems?.map((e) => e.toJson()).toList(),
  'errorMessage': ?instance.errorMessage,
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
      'flutterVersions': ?instance.flutterVersions,
    };

License _$LicenseFromJson(Map<String, dynamic> json) => License(
  spdxIdentifier: json['spdxIdentifier'] as String,
  range: json['range'] == null
      ? null
      : Range.fromJson(json['range'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LicenseToJson(License instance) => <String, dynamic>{
  'spdxIdentifier': instance.spdxIdentifier,
  'range': ?instance.range?.toJson(),
};

Range _$RangeFromJson(Map<String, dynamic> json) => Range(
  start: Position.fromJson(json['start'] as Map<String, dynamic>),
  end: Position.fromJson(json['end'] as Map<String, dynamic>),
  coverages: (json['coverages'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$RangeToJson(Range instance) => <String, dynamic>{
  'start': instance.start.toJson(),
  'end': instance.end.toJson(),
  'coverages': instance.coverages,
};

Position _$PositionFromJson(Map<String, dynamic> json) => Position(
  offset: (json['offset'] as num).toInt(),
  line: (json['line'] as num).toInt(),
  column: (json['column'] as num).toInt(),
);

Map<String, dynamic> _$PositionToJson(Position instance) => <String, dynamic>{
  'offset': instance.offset,
  'line': instance.line,
  'column': instance.column,
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
        _$RepositoryStatusEnumMap,
        json['repositoryStatus'],
      ),
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
      'homepageUrl': ?instance.homepageUrl,
      'repositoryUrl': ?instance.repositoryUrl,
      'issueTrackerUrl': ?instance.issueTrackerUrl,
      'documentationUrl': ?instance.documentationUrl,
      'fundingUrls': ?instance.fundingUrls,
      'repositoryStatus': ?_$RepositoryStatusEnumMap[instance.repositoryStatus],
      'repository': ?instance.repository?.toJson(),
      'contributingUrl': ?instance.contributingUrl,
      'licenses': ?instance.licenses?.map((e) => e.toJson()).toList(),
      'grantedPoints': ?instance.grantedPoints,
      'maxPoints': ?instance.maxPoints,
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
  provider: $enumDecodeNullable(_$RepositoryProviderEnumMap, json['provider']),
  host: json['host'] as String,
  repository: json['repository'] as String?,
  branch: json['branch'] as String?,
  path: json['path'] as String?,
);

Map<String, dynamic> _$RepositoryToJson(Repository instance) =>
    <String, dynamic>{
      'provider': _$RepositoryProviderEnumMap[instance.provider]!,
      'host': instance.host,
      'repository': ?instance.repository,
      'branch': ?instance.branch,
      'path': ?instance.path,
    };

const _$RepositoryProviderEnumMap = {
  RepositoryProvider.github: 'github',
  RepositoryProvider.gitlab: 'gitlab',
  RepositoryProvider.unknown: 'unknown',
};

UrlProblem _$UrlProblemFromJson(Map<String, dynamic> json) =>
    UrlProblem(url: json['url'] as String, problem: json['problem'] as String);

Map<String, dynamic> _$UrlProblemToJson(UrlProblem instance) =>
    <String, dynamic>{'url': instance.url, 'problem': instance.problem};
