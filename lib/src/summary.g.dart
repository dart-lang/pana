// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.summary;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

DartFileSummary _$DartFileSummaryFromJson(Map<String, dynamic> json) =>
    new DartFileSummary(
        json['uri'] as String,
        json['size'] as int,
        json['isFormatted'] as bool,
        (json['analyzerItems'] as List)
            ?.map((e) => e == null
                ? null
                : new AnalyzerOutput.fromJson(e as Map<String, dynamic>))
            ?.toList(),
        (json['directLibs'] as List)?.map((e) => e as String)?.toList(),
        (json['transitiveLibs'] as List)?.map((e) => e as String)?.toList(),
        json['platform'] == null
            ? null
            : new PlatformInfo.fromJson(
                json['platform'] as Map<String, dynamic>));

abstract class _$DartFileSummarySerializerMixin {
  String get uri;
  int get size;
  bool get isFormatted;
  List<AnalyzerOutput> get analyzerItems;
  List<String> get directLibs;
  List<String> get transitiveLibs;
  PlatformInfo get platform;
  Map<String, dynamic> toJson() {
    var $map = <String, dynamic>{};
    void $writeNotNull(String key, dynamic value) {
      if (value != null) {
        $map[key] = value;
      }
    }

    $map['uri'] = uri;
    $map['size'] = size;
    $map['isFormatted'] = isFormatted;
    $map['analyzerItems'] = analyzerItems;
    $writeNotNull('directLibs', directLibs);
    $writeNotNull('transitiveLibs', transitiveLibs);
    $writeNotNull('platform', platform);
    return $map;
  }
}

Summary _$SummaryFromJson(Map<String, dynamic> json) => new Summary(
    new Version.parse(json['panaVersion']),
    json['sdkVersion'] as String,
    json['packageName'] as String,
    new Version.parse(json['packageVersion']),
    json['pubSummary'] == null
        ? null
        : new PubSummary.fromJson(json['pubSummary'] as Map<String, dynamic>),
    json['dartFiles'] == null
        ? null
        : new Map<String, DartFileSummary>.fromIterables(
            (json['dartFiles'] as Map<String, dynamic>).keys,
            (json['dartFiles'] as Map).values.map((e) => e == null
                ? null
                : new DartFileSummary.fromJson(e as Map<String, dynamic>))),
    (json['issues'] as List)
        ?.map((e) => e == null
            ? null
            : new AnalyzerIssue.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    json['license'] == null
        ? null
        : new License.fromJson(json['license'] as Map<String, dynamic>),
    flutterVersion: json['flutterVersion'] as Map<String, dynamic>);

abstract class _$SummarySerializerMixin {
  Version get panaVersion;
  String get sdkVersion;
  Map<String, Object> get flutterVersion;
  String get packageName;
  Version get packageVersion;
  PubSummary get pubSummary;
  Map<String, DartFileSummary> get dartFiles;
  License get license;
  List<AnalyzerIssue> get issues;
  Map<String, dynamic> toJson() {
    var $map = <String, dynamic>{};
    void $writeNotNull(String key, dynamic value) {
      if (value != null) {
        $map[key] = value;
      }
    }

    $map['panaVersion'] = panaVersion.toString();
    $map['sdkVersion'] = sdkVersion;
    $writeNotNull('flutterVersion', flutterVersion);
    $map['packageName'] = packageName;
    $map['packageVersion'] = packageVersion.toString();
    $map['pubSummary'] = pubSummary;
    $map['dartFiles'] = dartFiles;
    $map['license'] = license;
    $writeNotNull('issues', issues);
    return $map;
  }
}

AnalyzerIssue _$AnalyzerIssueFromJson(Map<String, dynamic> json) =>
    new AnalyzerIssue(
        json['scope'] as String, json['message'] as String, json['code']);

abstract class _$AnalyzerIssueSerializerMixin {
  String get scope;
  String get message;
  dynamic get code;
  Map<String, dynamic> toJson() {
    var $map = <String, dynamic>{};
    void $writeNotNull(String key, dynamic value) {
      if (value != null) {
        $map[key] = value;
      }
    }

    $map['scope'] = scope;
    $map['message'] = message;
    $writeNotNull('code', code);
    return $map;
  }
}
