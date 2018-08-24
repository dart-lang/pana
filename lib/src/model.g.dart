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
      packageVersion: json['packageVersion'] == null
          ? null
          : new Version.parse(json['packageVersion'] as String),
      pubspec: json['pubspec'] == null
          ? null
          : Pubspec.fromJson(json['pubspec'] as Map<String, dynamic>),
      pkgResolution: json['pkgResolution'] == null
          ? null
          : PkgResolution.fromJson(
              json['pkgResolution'] as Map<String, dynamic>),
      dartFiles: (json['dartFiles'] as Map<String, dynamic>)?.map((k, e) =>
          MapEntry(
              k,
              e == null
                  ? null
                  : DartFileSummary.fromJson(e as Map<String, dynamic>))),
      platform: json['platform'] == null
          ? null
          : DartPlatform.fromJson(json['platform'] as Map<String, dynamic>),
      licenses: (json['licenses'] as List)
          ?.map((e) => e == null
              ? null
              : LicenseFile.fromJson(e as Map<String, dynamic>))
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
          ?.toList());
}

abstract class _$SummarySerializerMixin {
  PanaRuntimeInfo get runtimeInfo;
  String get packageName;
  Version get packageVersion;
  Pubspec get pubspec;
  DartPlatform get platform;
  List<LicenseFile> get licenses;
  Health get health;
  Maintenance get maintenance;
  List<Suggestion> get suggestions;
  PkgResolution get pkgResolution;
  Map<String, DartFileSummary> get dartFiles;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'runtimeInfo': runtimeInfo,
      'packageName': packageName,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('packageVersion', packageVersion?.toString());
    writeNotNull('pubspec', pubspec);
    val['platform'] = platform;
    val['licenses'] = licenses;
    writeNotNull('health', health);
    writeNotNull('maintenance', maintenance);
    writeNotNull('suggestions', suggestions);
    writeNotNull('pkgResolution', pkgResolution);
    writeNotNull('dartFiles', dartFiles);
    return val;
  }
}

PanaRuntimeInfo _$PanaRuntimeInfoFromJson(Map<String, dynamic> json) {
  return PanaRuntimeInfo(
      panaVersion: json['panaVersion'] as String,
      sdkVersion: json['sdkVersion'] as String,
      flutterVersions: json['flutterVersions'] as Map<String, dynamic>);
}

abstract class _$PanaRuntimeInfoSerializerMixin {
  String get panaVersion;
  String get sdkVersion;
  Map<String, dynamic> get flutterVersions;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'panaVersion': panaVersion,
      'sdkVersion': sdkVersion,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('flutterVersions', flutterVersions);
    return val;
  }
}

DartFileSummary _$DartFileSummaryFromJson(Map<String, dynamic> json) {
  return DartFileSummary(
      uri: json['uri'] as String,
      size: json['size'] as int,
      isFormatted: json['isFormatted'] as bool,
      codeProblems: (json['codeProblems'] as List)
          ?.map((e) => e == null
              ? null
              : CodeProblem.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      directLibs:
          (json['directLibs'] as List)?.map((e) => e as String)?.toList(),
      transitiveLibs:
          (json['transitiveLibs'] as List)?.map((e) => e as String)?.toList(),
      platform: json['platform'] == null
          ? null
          : DartPlatform.fromJson(json['platform'] as Map<String, dynamic>));
}

abstract class _$DartFileSummarySerializerMixin {
  String get uri;
  int get size;
  bool get isFormatted;
  List<CodeProblem> get codeProblems;
  List<String> get directLibs;
  List<String> get transitiveLibs;
  DartPlatform get platform;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'uri': uri,
      'size': size,
      'isFormatted': isFormatted,
      'codeProblems': codeProblems,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('directLibs', directLibs);
    writeNotNull('transitiveLibs', transitiveLibs);
    writeNotNull('platform', platform);
    return val;
  }
}

Suggestion _$SuggestionFromJson(Map<String, dynamic> json) {
  return Suggestion(json['code'] as String, json['level'] as String,
      json['title'] as String, json['description'] as String,
      file: json['file'] as String, score: (json['score'] as num)?.toDouble());
}

abstract class _$SuggestionSerializerMixin {
  String get code;
  String get level;
  String get title;
  String get description;
  String get file;
  double get score;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'code': code,
      'level': level,
      'title': title,
      'description': description,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('file', file);
    writeNotNull('score', score);
    return val;
  }
}

DartPlatform _$DartPlatformFromJson(Map<String, dynamic> json) {
  return DartPlatform(
      (json['components'] as List)?.map((e) => e as String)?.toList(),
      (json['uses'] as Map<String, dynamic>)?.map(
          (k, e) => MapEntry(k, _$enumDecodeNullable(_$PlatformUseEnumMap, e))),
      reason: json['reason'] as String);
}

abstract class _$DartPlatformSerializerMixin {
  List<String> get components;
  Map<String, PlatformUse> get uses;
  String get reason;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('components', components);
    writeNotNull(
        'uses', uses?.map((k, e) => MapEntry(k, _$PlatformUseEnumMap[e])));
    writeNotNull('reason', reason);
    return val;
  }
}

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError(
              '`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$PlatformUseEnumMap = <PlatformUse, dynamic>{
  PlatformUse.allowed: 'allowed',
  PlatformUse.used: 'used',
  PlatformUse.conflict: 'conflict',
  PlatformUse.forbidden: 'forbidden'
};

PkgResolution _$PkgResolutionFromJson(Map<String, dynamic> json) {
  return PkgResolution((json['dependencies'] as List)
      ?.map((e) =>
          e == null ? null : PkgDependency.fromJson(e as Map<String, dynamic>))
      ?.toList());
}

abstract class _$PkgResolutionSerializerMixin {
  List<PkgDependency> get dependencies;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'dependencies': dependencies};
}

PkgDependency _$PkgDependencyFromJson(Map<String, dynamic> json) {
  return PkgDependency(
      package: json['package'] as String,
      dependencyType: json['dependencyType'] as String,
      constraintType: json['constraintType'] as String,
      constraint: json['constraint'] == null
          ? null
          : new VersionConstraint.parse(json['constraint'] as String),
      resolved: json['resolved'] == null
          ? null
          : new Version.parse(json['resolved'] as String),
      available: json['available'] == null
          ? null
          : new Version.parse(json['available'] as String),
      errors: (json['errors'] as List)?.map((e) => e as String)?.toList());
}

abstract class _$PkgDependencySerializerMixin {
  String get package;
  String get dependencyType;
  String get constraintType;
  VersionConstraint get constraint;
  Version get resolved;
  Version get available;
  List<String> get errors;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'package': package,
      'dependencyType': dependencyType,
      'constraintType': constraintType,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('constraint', constraint?.toString());
    writeNotNull('resolved', resolved?.toString());
    writeNotNull('available', available?.toString());
    writeNotNull('errors', errors);
    return val;
  }
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
          ?.toList());
}

abstract class _$HealthSerializerMixin {
  bool get analyzeProcessFailed;
  bool get formatProcessFailed;
  bool get resolveProcessFailed;
  int get analyzerErrorCount;
  int get analyzerWarningCount;
  int get analyzerHintCount;
  int get platformConflictCount;
  List<Suggestion> get suggestions;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'analyzeProcessFailed': analyzeProcessFailed,
      'formatProcessFailed': formatProcessFailed,
      'resolveProcessFailed': resolveProcessFailed,
      'analyzerErrorCount': analyzerErrorCount,
      'analyzerWarningCount': analyzerWarningCount,
      'analyzerHintCount': analyzerHintCount,
      'platformConflictCount': platformConflictCount,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('suggestions', suggestions);
    return val;
  }
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
          ?.toList());
}

abstract class _$MaintenanceSerializerMixin {
  bool get missingChangelog;
  bool get missingExample;
  bool get missingReadme;
  bool get missingAnalysisOptions;
  bool get oldAnalysisOptions;
  bool get strongModeEnabled;
  bool get isExperimentalVersion;
  bool get isPreReleaseVersion;
  bool get dartdocSuccessful;
  List<Suggestion> get suggestions;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'missingChangelog': missingChangelog,
      'missingExample': missingExample,
      'missingReadme': missingReadme,
      'missingAnalysisOptions': missingAnalysisOptions,
      'oldAnalysisOptions': oldAnalysisOptions,
      'strongModeEnabled': strongModeEnabled,
      'isExperimentalVersion': isExperimentalVersion,
      'isPreReleaseVersion': isPreReleaseVersion,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('dartdocSuccessful', dartdocSuccessful);
    writeNotNull('suggestions', suggestions);
    return val;
  }
}

LicenseFile _$LicenseFileFromJson(Map<String, dynamic> json) {
  return LicenseFile(json['path'] as String, json['name'] as String,
      version: json['version'] as String, url: json['url'] as String);
}

abstract class _$LicenseFileSerializerMixin {
  String get path;
  String get name;
  String get version;
  String get url;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'path': path,
      'name': name,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('version', version);
    writeNotNull('url', url);
    return val;
  }
}

CodeProblem _$CodeProblemFromJson(Map<String, dynamic> json) {
  return CodeProblem(
      severity: json['severity'] as String,
      errorType: json['errorType'] as String,
      errorCode: json['errorCode'] as String,
      description: json['description'] as String,
      file: json['file'] as String,
      line: json['line'] as int,
      col: json['col'] as int);
}

abstract class _$CodeProblemSerializerMixin {
  String get severity;
  String get errorType;
  String get errorCode;
  String get file;
  int get line;
  int get col;
  String get description;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'severity': severity,
        'errorType': errorType,
        'errorCode': errorCode,
        'file': file,
        'line': line,
        'col': col,
        'description': description
      };
}
