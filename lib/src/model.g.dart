// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

Summary _$SummaryFromJson(Map<String, dynamic> json) => new Summary(
    new Version.parse(json['panaVersion']),
    new Version.parse(json['sdkVersion']),
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
    json['platform'] == null
        ? null
        : new DartPlatform.fromJson(json['platform'] as Map<String, dynamic>),
    (json['licenses'] as List)
        ?.map((e) => e == null
            ? null
            : new LicenseFile.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    json['fitness'] == null
        ? null
        : new Fitness.fromJson(json['fitness'] as Map<dynamic, dynamic>),
    json['maintenance'] == null
        ? null
        : new Maintenance.fromJson(json['maintenance'] as Map<String, dynamic>),
    (json['suggestions'] as List)
        ?.map((e) => e == null
            ? null
            : new Suggestion.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    flutterVersion: json['flutterVersion'] as Map<String, dynamic>);

abstract class _$SummarySerializerMixin {
  Version get panaVersion;
  Version get sdkVersion;
  Map<String, Object> get flutterVersion;
  String get packageName;
  Version get packageVersion;
  Pubspec get pubspec;
  DartPlatform get platform;
  List<LicenseFile> get licenses;
  Maintenance get maintenance;
  Fitness get fitness;
  List<Suggestion> get suggestions;
  PkgResolution get pkgResolution;
  Map<String, DartFileSummary> get dartFiles;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'panaVersion': panaVersion.toString(),
      'sdkVersion': sdkVersion.toString(),
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
    val['platform'] = platform;
    val['licenses'] = licenses;
    writeNotNull('maintenance', maintenance);
    val['fitness'] = fitness;
    writeNotNull('suggestions', suggestions);
    val['pkgResolution'] = pkgResolution;
    val['dartFiles'] = dartFiles;
    return val;
  }
}

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
            : new DartPlatform.fromJson(
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
  DartPlatform get platform;
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

Suggestion _$SuggestionFromJson(Map<String, dynamic> json) => new Suggestion(
    json['level'] as String,
    json['title'] as String,
    json['description'] as String,
    file: json['file'] as String,
    penalty: json['penalty'] == null
        ? null
        : new Penalty.fromJson(json['penalty'] as Map<String, dynamic>));

abstract class _$SuggestionSerializerMixin {
  String get level;
  String get title;
  String get description;
  String get file;
  Penalty get penalty;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
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
    writeNotNull('penalty', penalty);
    return val;
  }
}

Penalty _$PenaltyFromJson(Map<String, dynamic> json) => new Penalty(
    amount: json['amount'] as int, fraction: json['fraction'] as int);

abstract class _$PenaltySerializerMixin {
  int get amount;
  int get fraction;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('amount', amount);
    writeNotNull('fraction', fraction);
    return val;
  }
}

DartPlatform _$DartPlatformFromJson(Map<String, dynamic> json) =>
    new DartPlatform(
        (json['components'] as List)?.map((e) => e as String)?.toList(),
        json['uses'] == null
            ? null
            : new Map<String, PlatformUse>.fromIterables(
                (json['uses'] as Map<String, dynamic>).keys,
                (json['uses'] as Map).values.map((e) => e == null
                    ? null
                    : PlatformUse.values
                        .singleWhere((x) => x.toString() == 'PlatformUse.$e'))),
        reason: json['reason'] as String);

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
        'uses',
        uses == null
            ? null
            : new Map<String, dynamic>.fromIterables(
                uses.keys,
                uses.values.map(
                    (e) => e == null ? null : e.toString().split('.')[1])));
    writeNotNull('reason', reason);
    return val;
  }
}

PkgResolution _$PkgResolutionFromJson(Map<String, dynamic> json) =>
    new PkgResolution((json['dependencies'] as List)
        ?.map((e) => e == null
            ? null
            : new PkgDependency.fromJson(e as Map<String, dynamic>))
        ?.toList());

abstract class _$PkgResolutionSerializerMixin {
  List<PkgDependency> get dependencies;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'dependencies': dependencies};
}

PkgDependency _$PkgDependencyFromJson(Map<String, dynamic> json) =>
    new PkgDependency(
        json['package'] as String,
        json['dependencyType'] as String,
        json['constraintType'] as String,
        json['constraint'] == null
            ? null
            : new VersionConstraint.parse(json['constraint']),
        json['resolved'] == null ? null : new Version.parse(json['resolved']),
        json['available'] == null ? null : new Version.parse(json['available']),
        (json['errors'] as List)?.map((e) => e as String)?.toList());

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
