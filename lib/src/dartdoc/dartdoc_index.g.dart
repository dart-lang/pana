// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'dartdoc_index.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DartdocIndexEntry _$DartdocIndexEntryFromJson(Map<String, dynamic> json) =>
    DartdocIndexEntry(
      name: json['name'] as String?,
      qualifiedName: json['qualifiedName'] as String?,
      href: json['href'] as String?,
      kind: (json['kind'] as num?)?.toInt(),
      packageRank: (json['packageRank'] as num?)?.toInt(),
      overriddenDepth: (json['overriddenDepth'] as num?)?.toInt(),
      packageName: json['packageName'] as String?,
      desc: json['desc'] as String?,
      enclosedBy: json['enclosedBy'] == null
          ? null
          : DartdocIndexEntryEnclosedBy.fromJson(
              json['enclosedBy'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$DartdocIndexEntryToJson(DartdocIndexEntry instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'qualifiedName': ?instance.qualifiedName,
      'href': ?instance.href,
      'kind': ?instance.kind,
      'packageRank': ?instance.packageRank,
      'overriddenDepth': ?instance.overriddenDepth,
      'packageName': ?instance.packageName,
      'desc': ?instance.desc,
      'enclosedBy': ?instance.enclosedBy?.toJson(),
    };

DartdocIndexEntryEnclosedBy _$DartdocIndexEntryEnclosedByFromJson(
  Map<String, dynamic> json,
) => DartdocIndexEntryEnclosedBy(
  name: json['name'] as String?,
  kind: (json['kind'] as num?)?.toInt(),
  href: json['href'] as String?,
);

Map<String, dynamic> _$DartdocIndexEntryEnclosedByToJson(
  DartdocIndexEntryEnclosedBy instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'kind': ?instance.kind,
  'href': ?instance.href,
};
