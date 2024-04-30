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

Map<String, dynamic> _$DartdocIndexEntryToJson(DartdocIndexEntry instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('qualifiedName', instance.qualifiedName);
  writeNotNull('href', instance.href);
  writeNotNull('kind', instance.kind);
  writeNotNull('packageRank', instance.packageRank);
  writeNotNull('overriddenDepth', instance.overriddenDepth);
  writeNotNull('packageName', instance.packageName);
  writeNotNull('desc', instance.desc);
  writeNotNull('enclosedBy', instance.enclosedBy?.toJson());
  return val;
}

DartdocIndexEntryEnclosedBy _$DartdocIndexEntryEnclosedByFromJson(
        Map<String, dynamic> json) =>
    DartdocIndexEntryEnclosedBy(
      name: json['name'] as String?,
      kind: (json['kind'] as num?)?.toInt(),
      href: json['href'] as String?,
    );

Map<String, dynamic> _$DartdocIndexEntryEnclosedByToJson(
    DartdocIndexEntryEnclosedBy instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('kind', instance.kind);
  writeNotNull('href', instance.href);
  return val;
}
