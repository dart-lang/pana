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
              json['enclosedBy'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DartdocIndexEntryToJson(DartdocIndexEntry instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.qualifiedName case final value?) 'qualifiedName': value,
      if (instance.href case final value?) 'href': value,
      if (instance.kind case final value?) 'kind': value,
      if (instance.packageRank case final value?) 'packageRank': value,
      if (instance.overriddenDepth case final value?) 'overriddenDepth': value,
      if (instance.packageName case final value?) 'packageName': value,
      if (instance.desc case final value?) 'desc': value,
      if (instance.enclosedBy?.toJson() case final value?) 'enclosedBy': value,
    };

DartdocIndexEntryEnclosedBy _$DartdocIndexEntryEnclosedByFromJson(
        Map<String, dynamic> json) =>
    DartdocIndexEntryEnclosedBy(
      name: json['name'] as String?,
      kind: (json['kind'] as num?)?.toInt(),
      href: json['href'] as String?,
    );

Map<String, dynamic> _$DartdocIndexEntryEnclosedByToJson(
        DartdocIndexEntryEnclosedBy instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.kind case final value?) 'kind': value,
      if (instance.href case final value?) 'href': value,
    };
