// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shapes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PackageShape _$PackageShapeFromJson(Map<String, dynamic> json) => PackageShape(
      libraries: (json['libraries'] as List<dynamic>)
          .map((e) => LibraryShape.fromJson(e as Map<String, dynamic>))
          .toList(),
      getters: (json['getters'] as List<dynamic>)
          .map((e) => GlobalPropertyShape.fromJson(e as Map<String, dynamic>))
          .toList(),
      setters: (json['setters'] as List<dynamic>)
          .map((e) => GlobalPropertyShape.fromJson(e as Map<String, dynamic>))
          .toList(),
      functions: (json['functions'] as List<dynamic>)
          .map((e) => FunctionShape.fromJson(e as Map<String, dynamic>))
          .toList(),
      classes: (json['classes'] as List<dynamic>)
          .map((e) => ClassShape.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PackageShapeToJson(PackageShape instance) =>
    <String, dynamic>{
      'libraries': instance.libraries.map((e) => e.toJson()).toList(),
      'getters': instance.getters.map((e) => e.toJson()).toList(),
      'setters': instance.setters.map((e) => e.toJson()).toList(),
      'functions': instance.functions.map((e) => e.toJson()).toList(),
      'classes': instance.classes.map((e) => e.toJson()).toList(),
    };

LibraryShape _$LibraryShapeFromJson(Map<String, dynamic> json) => LibraryShape(
      uri: json['uri'] as String,
      exportedGetters: (json['exportedGetters'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      exportedSetters: (json['exportedSetters'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      exportedFunctions: (json['exportedFunctions'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      exportedClasses: (json['exportedClasses'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
    );

Map<String, dynamic> _$LibraryShapeToJson(LibraryShape instance) =>
    <String, dynamic>{
      'uri': instance.uri,
      'exportedGetters': instance.exportedGetters,
      'exportedSetters': instance.exportedSetters,
      'exportedFunctions': instance.exportedFunctions,
      'exportedClasses': instance.exportedClasses,
    };

ClassShape _$ClassShapeFromJson(Map<String, dynamic> json) => ClassShape(
      id: json['id'] as int,
      name: json['name'] as String,
      getters: (json['getters'] as List<dynamic>)
          .map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
          .toList(),
      setters: (json['setters'] as List<dynamic>)
          .map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
          .toList(),
      methods: (json['methods'] as List<dynamic>)
          .map((e) => MethodShape.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ClassShapeToJson(ClassShape instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'getters': instance.getters.map((e) => e.toJson()).toList(),
      'setters': instance.setters.map((e) => e.toJson()).toList(),
      'methods': instance.methods.map((e) => e.toJson()).toList(),
    };

MethodShape _$MethodShapeFromJson(Map<String, dynamic> json) => MethodShape(
      name: json['name'] as String,
    );

Map<String, dynamic> _$MethodShapeToJson(MethodShape instance) =>
    <String, dynamic>{
      'name': instance.name,
    };

FunctionShape _$FunctionShapeFromJson(Map<String, dynamic> json) =>
    FunctionShape(
      id: json['id'] as int,
      name: json['name'] as String,
    );

Map<String, dynamic> _$FunctionShapeToJson(FunctionShape instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };

PropertyShape _$PropertyShapeFromJson(Map<String, dynamic> json) =>
    PropertyShape(
      name: json['name'] as String,
    );

Map<String, dynamic> _$PropertyShapeToJson(PropertyShape instance) =>
    <String, dynamic>{
      'name': instance.name,
    };

GlobalPropertyShape _$GlobalPropertyShapeFromJson(Map<String, dynamic> json) =>
    GlobalPropertyShape(
      id: json['id'] as int,
      name: json['name'] as String,
    );

Map<String, dynamic> _$GlobalPropertyShapeToJson(
        GlobalPropertyShape instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };
