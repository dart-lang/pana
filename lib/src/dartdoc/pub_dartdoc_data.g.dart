// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package

part of 'pub_dartdoc_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PubDartdocData _$PubDartdocDataFromJson(Map<String, dynamic> json) =>
    PubDartdocData(
      coverage: json['coverage'] == null
          ? null
          : Coverage.fromJson(json['coverage'] as Map<String, dynamic>),
      apiElements: (json['apiElements'] as List<dynamic>?)
          ?.map((e) => ApiElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PubDartdocDataToJson(PubDartdocData instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('coverage', instance.coverage?.toJson());
  writeNotNull(
      'apiElements', instance.apiElements?.map((e) => e.toJson()).toList());
  return val;
}

ApiElement _$ApiElementFromJson(Map<String, dynamic> json) => ApiElement(
      name: json['name'] as String,
      parent: json['parent'] as String?,
      source: json['source'] as String?,
      href: json['href'] as String?,
      documentation: json['documentation'] as String?,
    );

Map<String, dynamic> _$ApiElementToJson(ApiElement instance) {
  final val = <String, dynamic>{
    'name': instance.name,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('parent', instance.parent);
  writeNotNull('source', instance.source);
  writeNotNull('href', instance.href);
  writeNotNull('documentation', instance.documentation);
  return val;
}

Coverage _$CoverageFromJson(Map<String, dynamic> json) => Coverage(
      total: json['total'] as int,
      documented: json['documented'] as int,
      symbolsMissingDocumentation:
          (json['symbolsMissingDocumentation'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    );

Map<String, dynamic> _$CoverageToJson(Coverage instance) {
  final val = <String, dynamic>{
    'total': instance.total,
    'documented': instance.documented,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull(
      'symbolsMissingDocumentation', instance.symbolsMissingDocumentation);
  return val;
}
