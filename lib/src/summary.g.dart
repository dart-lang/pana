// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.summary;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

DartFileSummary _$DartFileSummaryFromJson(
        Map<String, dynamic> json) =>
    new DartFileSummary(
        json['uri'] as String,
        json['size'] as int,
        json['isFormatted'] as bool,
        (json['codeProblems'] as List)
            ?.map((e) => e == null
                ? null
                : new CodeProblem.fromJson(e as Map<String, dynamic>))
            ?.toList(),
        (json['directLibs'] as List)?.map((e) => e as String)?.toList(),
        (json['transitiveLibs'] as List)?.map((e) => e as String)?.toList(),
        json['platform'] == null
            ? null
            : new PlatformInfo.fromJson(
                json['platform'] as Map<String, dynamic>),
        json['fitness'] == null
            ? null
            : new Fitness.fromJson(json['fitness'] as Map<dynamic, dynamic>));

abstract class _$DartFileSummarySerializerMixin {
  String get uri;
  int get size;
  bool get isFormatted;
  List<CodeProblem> get codeProblems;
  List<String> get directLibs;
  List<String> get transitiveLibs;
  PlatformInfo get platform;
  Fitness get fitness;
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
    writeNotNull('fitness', fitness);
    return val;
  }
}

Summary _$SummaryFromJson(Map<String, dynamic> json) => new Summary(
    new Version.parse(json['panaVersion']),
    json['sdkVersion'] as String,
    json['packageName'] as String,
    json['packageVersion'] == null
        ? null
        : new Version.parse(json['packageVersion']),
    json['pubspec'] == null
        ? null
        : new Pubspec.fromJson(json['pubspec'] as Map<String, dynamic>),
    json['pkgResolution'] == null
        ? null
        : new PkgResolution.fromJson(
            json['pkgResolution'] as Map<String, dynamic>),
    json['dartFiles'] == null
        ? null
        : new Map<String, DartFileSummary>.fromIterables(
            (json['dartFiles'] as Map<String, dynamic>).keys,
            (json['dartFiles'] as Map).values.map((e) => e == null
                ? null
                : new DartFileSummary.fromJson(e as Map<String, dynamic>))),
    (json['toolProblems'] as List)
        ?.map((e) => e == null
            ? null
            : new ToolProblem.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    json['license'] == null
        ? null
        : new License.fromJson(json['license'] as Map<String, dynamic>),
    json['fitness'] == null
        ? null
        : new Fitness.fromJson(json['fitness'] as Map<dynamic, dynamic>),
    flutterVersion: json['flutterVersion'] as Map<String, dynamic>);

abstract class _$SummarySerializerMixin {
  Version get panaVersion;
  String get sdkVersion;
  Map<String, Object> get flutterVersion;
  String get packageName;
  Version get packageVersion;
  Pubspec get pubspec;
  PkgResolution get pkgResolution;
  Map<String, DartFileSummary> get dartFiles;
  License get license;
  List<ToolProblem> get toolProblems;
  Fitness get fitness;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'panaVersion': panaVersion.toString(),
      'sdkVersion': sdkVersion,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('flutterVersion', flutterVersion);
    val['packageName'] = packageName;
    writeNotNull('packageVersion', packageVersion?.toString());
    val['pubspec'] = pubspec;
    val['pkgResolution'] = pkgResolution;
    val['dartFiles'] = dartFiles;
    val['license'] = license;
    writeNotNull('toolProblems', toolProblems);
    val['fitness'] = fitness;
    return val;
  }
}

ToolProblem _$ToolProblemFromJson(Map<String, dynamic> json) => new ToolProblem(
    json['tool'] as String, json['message'] as String, json['code']);

abstract class _$ToolProblemSerializerMixin {
  String get tool;
  String get message;
  dynamic get code;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'tool': tool,
      'message': message,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('code', code);
    return val;
  }
}
