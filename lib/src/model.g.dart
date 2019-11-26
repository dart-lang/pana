// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Summary _$SummaryFromJson(Map<String, dynamic> json) {
  return Summary(
    runtimeInfo:
        PanaRuntimeInfo.fromJson(json['runtimeInfo'] as Map<String, dynamic>),
    packageName: json['packageName'] as String,
    packageVersion:
        const VersionConverter().fromJson(json['packageVersion'] as String),
    pubspec: json['pubspec'] == null
        ? null
        : Pubspec.fromJson(json['pubspec'] as Map<String, dynamic>),
    pkgResolution: json['pkgResolution'] == null
        ? null
        : PkgResolution.fromJson(json['pkgResolution'] as Map<String, dynamic>),
    dartFiles: (json['dartFiles'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(
          k,
          e == null
              ? null
              : DartFileSummary.fromJson(e as Map<String, dynamic>)),
    ),
    platform: json['platform'] == null
        ? null
        : DartPlatform.fromJson(json['platform'] as Map<String, dynamic>),
    licenses: (json['licenses'] as List)
        ?.map((e) =>
            e == null ? null : LicenseFile.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    health: json['health'] == null
        ? null
        : Health.fromJson(json['health'] as Map<String, dynamic>),
    maintenance: json['maintenance'] == null
        ? null
        : Maintenance.fromJson(json['maintenance'] as Map<String, dynamic>),
    suggestions: (json['suggestions'] as List)
        ?.map((e) =>
            e == null ? null : Suggestion.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    stats: json['stats'] == null
        ? null
        : Stats.fromJson(json['stats'] as Map<String, dynamic>),
    tags: (json['tags'] as List)?.map((e) => e as String)?.toList(),
  );
}

Map<String, dynamic> _$SummaryToJson(Summary instance) {
  final val = <String, dynamic>{
    'runtimeInfo': instance.runtimeInfo,
    'packageName': instance.packageName,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('packageVersion',
      const VersionConverter().toJson(instance.packageVersion));
  writeNotNull('pubspec', instance.pubspec);
  val['platform'] = instance.platform;
  val['licenses'] = instance.licenses;
  writeNotNull('health', instance.health);
  writeNotNull('maintenance', instance.maintenance);
  writeNotNull('suggestions', instance.suggestions);
  writeNotNull('pkgResolution', instance.pkgResolution);
  writeNotNull('dartFiles', instance.dartFiles);
  writeNotNull('stats', instance.stats);
  writeNotNull('tags', instance.tags);
  return val;
}

PanaRuntimeInfo _$PanaRuntimeInfoFromJson(Map<String, dynamic> json) {
  return PanaRuntimeInfo(
    panaVersion: json['panaVersion'] as String,
    sdkVersion: json['sdkVersion'] as String,
    flutterVersions: json['flutterVersions'] as Map<String, dynamic>,
  );
}

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

DartFileSummary _$DartFileSummaryFromJson(Map<String, dynamic> json) {
  return DartFileSummary(
    uri: json['uri'] as String,
    size: json['size'] as int,
    isFormatted: json['isFormatted'] as bool,
    codeProblems: (json['codeProblems'] as List)
        ?.map((e) =>
            e == null ? null : CodeProblem.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    directLibs: (json['directLibs'] as List)?.map((e) => e as String)?.toList(),
    transitiveLibs:
        (json['transitiveLibs'] as List)?.map((e) => e as String)?.toList(),
    platform: json['platform'] == null
        ? null
        : DartPlatform.fromJson(json['platform'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$DartFileSummaryToJson(DartFileSummary instance) {
  final val = <String, dynamic>{
    'uri': instance.uri,
    'size': instance.size,
    'isFormatted': instance.isFormatted,
    'codeProblems': instance.codeProblems,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('directLibs', instance.directLibs);
  writeNotNull('transitiveLibs', instance.transitiveLibs);
  writeNotNull('platform', instance.platform);
  return val;
}

Suggestion _$SuggestionFromJson(Map<String, dynamic> json) {
  return Suggestion(
    json['code'] as String,
    json['level'] as String,
    json['title'] as String,
    json['description'] as String,
    file: json['file'] as String,
    score: (json['score'] as num)?.toDouble(),
  );
}

Map<String, dynamic> _$SuggestionToJson(Suggestion instance) {
  final val = <String, dynamic>{
    'code': instance.code,
    'level': instance.level,
    'title': instance.title,
    'description': instance.description,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('file', instance.file);
  writeNotNull('score', instance.score);
  return val;
}

DartPlatform _$DartPlatformFromJson(Map<String, dynamic> json) {
  return DartPlatform(
    (json['components'] as List)?.map((e) => e as String)?.toList(),
    (json['uses'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k, _$enumDecodeNullable(_$PlatformUseEnumMap, e)),
    ),
    reason: json['reason'] as String,
  );
}

Map<String, dynamic> _$DartPlatformToJson(DartPlatform instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('components', instance.components);
  writeNotNull('uses',
      instance.uses?.map((k, e) => MapEntry(k, _$PlatformUseEnumMap[e])));
  writeNotNull('reason', instance.reason);
  return val;
}

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$PlatformUseEnumMap = {
  PlatformUse.allowed: 'allowed',
  PlatformUse.used: 'used',
  PlatformUse.conflict: 'conflict',
  PlatformUse.forbidden: 'forbidden',
};

PkgResolution _$PkgResolutionFromJson(Map<String, dynamic> json) {
  return PkgResolution(
    (json['dependencies'] as List)
        ?.map((e) => e == null
            ? null
            : PkgDependency.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$PkgResolutionToJson(PkgResolution instance) =>
    <String, dynamic>{
      'dependencies': instance.dependencies,
    };

PkgDependency _$PkgDependencyFromJson(Map<String, dynamic> json) {
  return PkgDependency(
    package: json['package'] as String,
    dependencyType: json['dependencyType'] as String,
    constraintType: json['constraintType'] as String,
    constraint: const VersionConstraintConverter()
        .fromJson(json['constraint'] as String),
    resolved: const VersionConverter().fromJson(json['resolved'] as String),
    available: const VersionConverter().fromJson(json['available'] as String),
    errors: (json['errors'] as List)?.map((e) => e as String)?.toList(),
  );
}

Map<String, dynamic> _$PkgDependencyToJson(PkgDependency instance) {
  final val = <String, dynamic>{
    'package': instance.package,
    'dependencyType': instance.dependencyType,
    'constraintType': instance.constraintType,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('constraint',
      const VersionConstraintConverter().toJson(instance.constraint));
  writeNotNull('resolved', const VersionConverter().toJson(instance.resolved));
  writeNotNull(
      'available', const VersionConverter().toJson(instance.available));
  writeNotNull('errors', instance.errors);
  return val;
}

Health _$HealthFromJson(Map<String, dynamic> json) {
  return Health(
    analyzeProcessFailed: json['analyzeProcessFailed'] as bool,
    formatProcessFailed: json['formatProcessFailed'] as bool,
    resolveProcessFailed: json['resolveProcessFailed'] as bool,
    analyzerErrorCount: json['analyzerErrorCount'] as int,
    analyzerWarningCount: json['analyzerWarningCount'] as int,
    analyzerHintCount: json['analyzerHintCount'] as int,
    platformConflictCount: json['platformConflictCount'] as int,
    suggestions: (json['suggestions'] as List)
        ?.map((e) =>
            e == null ? null : Suggestion.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$HealthToJson(Health instance) {
  final val = <String, dynamic>{
    'analyzeProcessFailed': instance.analyzeProcessFailed,
    'formatProcessFailed': instance.formatProcessFailed,
    'resolveProcessFailed': instance.resolveProcessFailed,
    'analyzerErrorCount': instance.analyzerErrorCount,
    'analyzerWarningCount': instance.analyzerWarningCount,
    'analyzerHintCount': instance.analyzerHintCount,
    'platformConflictCount': instance.platformConflictCount,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('suggestions', instance.suggestions);
  return val;
}

Maintenance _$MaintenanceFromJson(Map<String, dynamic> json) {
  return Maintenance(
    missingChangelog: json['missingChangelog'] as bool,
    missingExample: json['missingExample'] as bool,
    missingReadme: json['missingReadme'] as bool,
    missingAnalysisOptions: json['missingAnalysisOptions'] as bool,
    oldAnalysisOptions: json['oldAnalysisOptions'] as bool,
    strongModeEnabled: json['strongModeEnabled'] as bool,
    isExperimentalVersion: json['isExperimentalVersion'] as bool,
    isPreReleaseVersion: json['isPreReleaseVersion'] as bool,
    dartdocSuccessful: json['dartdocSuccessful'] as bool,
    suggestions: (json['suggestions'] as List)
        ?.map((e) =>
            e == null ? null : Suggestion.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$MaintenanceToJson(Maintenance instance) {
  final val = <String, dynamic>{
    'missingChangelog': instance.missingChangelog,
    'missingExample': instance.missingExample,
    'missingReadme': instance.missingReadme,
    'missingAnalysisOptions': instance.missingAnalysisOptions,
    'oldAnalysisOptions': instance.oldAnalysisOptions,
    'strongModeEnabled': instance.strongModeEnabled,
    'isExperimentalVersion': instance.isExperimentalVersion,
    'isPreReleaseVersion': instance.isPreReleaseVersion,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('dartdocSuccessful', instance.dartdocSuccessful);
  writeNotNull('suggestions', instance.suggestions);
  return val;
}

LicenseFile _$LicenseFileFromJson(Map<String, dynamic> json) {
  return LicenseFile(
    json['path'] as String,
    json['name'] as String,
    version: json['version'] as String,
    url: json['url'] as String,
  );
}

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

CodeProblem _$CodeProblemFromJson(Map<String, dynamic> json) {
  return CodeProblem(
    severity: json['severity'] as String,
    errorType: json['errorType'] as String,
    errorCode: json['errorCode'] as String,
    description: json['description'] as String,
    file: json['file'] as String,
    line: json['line'] as int,
    col: json['col'] as int,
  );
}

Map<String, dynamic> _$CodeProblemToJson(CodeProblem instance) =>
    <String, dynamic>{
      'severity': instance.severity,
      'errorType': instance.errorType,
      'errorCode': instance.errorCode,
      'file': instance.file,
      'line': instance.line,
      'col': instance.col,
      'description': instance.description,
    };

Stats _$StatsFromJson(Map<String, dynamic> json) {
  return Stats(
    analyzeProcessElapsed: json['analyzeProcessElapsed'] as int,
    formatProcessElapsed: json['formatProcessElapsed'] as int,
    resolveProcessElapsed: json['resolveProcessElapsed'] as int,
    totalElapsed: json['totalElapsed'] as int,
  );
}

Map<String, dynamic> _$StatsToJson(Stats instance) => <String, dynamic>{
      'analyzeProcessElapsed': instance.analyzeProcessElapsed,
      'formatProcessElapsed': instance.formatProcessElapsed,
      'resolveProcessElapsed': instance.resolveProcessElapsed,
      'totalElapsed': instance.totalElapsed,
    };
