// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.pub_summary;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

PubSummary _$PubSummaryFromJson(Map<String, dynamic> json) => new PubSummary(
    json['packages'] == null
        ? null
        : new Map<String, Version>.fromIterables(
            (json['packages'] as Map<String, dynamic>).keys,
            (json['packages'] as Map)
                .values
                .map((e) => e == null ? null : new Version.parse(e))),
    json['availablePackages'] == null
        ? null
        : new Map<String, Version>.fromIterables(
            (json['availablePackages'] as Map<String, dynamic>).keys,
            (json['availablePackages'] as Map)
                .values
                .map((e) => e == null ? null : new Version.parse(e))),
    json['pubspecContent'] as Map<String, dynamic>);

abstract class _$PubSummarySerializerMixin {
  Map<String, Object> get pubspec;
  Map<String, Version> get packageVersions;
  Map<String, Version> get availableVersions;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'pubspecContent': pubspec,
        'packages': packageVersions == null
            ? null
            : new Map<String, dynamic>.fromIterables(packageVersions.keys,
                packageVersions.values.map((e) => e?.toString())),
        'availablePackages': availableVersions == null
            ? null
            : new Map<String, dynamic>.fromIterables(availableVersions.keys,
                availableVersions.values.map((e) => e?.toString()))
      };
}

PkgDependency _$PkgDependencyFromJson(Map<String, dynamic> json) =>
    new PkgDependency(
        json['package'] as String,
        json['isDev'] as bool,
        json['constraint'] == null
            ? null
            : new VersionConstraint.parse(json['constraint']),
        json['resolved'] == null ? null : new Version.parse(json['resolved']),
        json['available'] == null
            ? null
            : new Version.parse(json['available']));

abstract class _$PkgDependencySerializerMixin {
  String get package;
  bool get isDev;
  VersionConstraint get constraint;
  Version get resolved;
  Version get available;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'package': package,
        'isDev': isDev,
        'constraint': constraint?.toString(),
        'resolved': resolved?.toString(),
        'available': available?.toString()
      };
}
