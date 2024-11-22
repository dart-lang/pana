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

Map<String, dynamic> _$PubDartdocDataToJson(PubDartdocData instance) =>
    <String, dynamic>{
      if (instance.coverage?.toJson() case final value?) 'coverage': value,
      if (instance.apiElements?.map((e) => e.toJson()).toList()
          case final value?)
        'apiElements': value,
    };

ApiElement _$ApiElementFromJson(Map<String, dynamic> json) => ApiElement(
      name: json['name'] as String,
      parent: json['parent'] as String?,
      source: json['source'] as String?,
      href: json['href'] as String?,
      documentation: json['documentation'] as String?,
    );

Map<String, dynamic> _$ApiElementToJson(ApiElement instance) =>
    <String, dynamic>{
      'name': instance.name,
      if (instance.parent case final value?) 'parent': value,
      if (instance.source case final value?) 'source': value,
      if (instance.href case final value?) 'href': value,
      if (instance.documentation case final value?) 'documentation': value,
    };

Coverage _$CoverageFromJson(Map<String, dynamic> json) => Coverage(
      total: (json['total'] as num).toInt(),
      documented: (json['documented'] as num).toInt(),
      symbolsMissingDocumentation:
          (json['symbolsMissingDocumentation'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    );

Map<String, dynamic> _$CoverageToJson(Coverage instance) => <String, dynamic>{
      'total': instance.total,
      'documented': instance.documented,
      if (instance.symbolsMissingDocumentation case final value?)
        'symbolsMissingDocumentation': value,
    };
