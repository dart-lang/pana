// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shapes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PackageShape _$PackageShapeFromJson(Map<String, dynamic> json) => PackageShape(
      name: json['name'] as String,
      version: json['version'] as String,
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
      extensions: (json['extensions'] as List<dynamic>)
          .map((e) => ExtensionShape.fromJson(e as Map<String, dynamic>))
          .toList(),
      typedefs: (json['typedefs'] as List<dynamic>)
          .map((e) => TypedefShape.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PackageShapeToJson(PackageShape instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
      'libraries': instance.libraries.map((e) => e.toJson()).toList(),
      'getters': instance.getters.map((e) => e.toJson()).toList(),
      'setters': instance.setters.map((e) => e.toJson()).toList(),
      'functions': instance.functions.map((e) => e.toJson()).toList(),
      'classes': instance.classes.map((e) => e.toJson()).toList(),
      'extensions': instance.extensions.map((e) => e.toJson()).toList(),
      'typedefs': instance.typedefs.map((e) => e.toJson()).toList(),
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
      exportedExtensions: (json['exportedExtensions'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      exportedTypedefs: (json['exportedTypedefs'] as List<dynamic>)
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
      'exportedExtensions': instance.exportedExtensions,
      'exportedTypedefs': instance.exportedTypedefs,
    };

ClassShape _$ClassShapeFromJson(Map<String, dynamic> json) => ClassShape(
      id: json['id'] as int,
      name: json['name'] as String,
      getters: (json['getters'] as List<dynamic>?)
              ?.map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      setters: (json['setters'] as List<dynamic>?)
              ?.map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      methods: (json['methods'] as List<dynamic>?)
              ?.map((e) => MethodShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      staticGetters: (json['staticGetters'] as List<dynamic>?)
              ?.map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      staticSetters: (json['staticSetters'] as List<dynamic>?)
              ?.map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      staticMethods: (json['staticMethods'] as List<dynamic>?)
              ?.map((e) => MethodShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      unnamedConstructor: json['unnamedConstructor'] as bool,
      namedConstructors: (json['namedConstructors'] as List<dynamic>?)
              ?.map((e) =>
                  NamedConstructorShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      annotations: (json['annotations'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$AnnotationEnumMap, e))
              .toList() ??
          [],
    );

Map<String, dynamic> _$ClassShapeToJson(ClassShape instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'name': instance.name,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('getters', _listContentsOrNull(instance.getters));
  writeNotNull('setters', _listContentsOrNull(instance.setters));
  writeNotNull('methods', _listContentsOrNull(instance.methods));
  writeNotNull('staticGetters', _listContentsOrNull(instance.staticGetters));
  writeNotNull('staticSetters', _listContentsOrNull(instance.staticSetters));
  writeNotNull('staticMethods', _listContentsOrNull(instance.staticMethods));
  val['unnamedConstructor'] = instance.unnamedConstructor;
  writeNotNull(
      'namedConstructors', _listContentsOrNull(instance.namedConstructors));
  writeNotNull('annotations', _listAnnotationsOrNull(instance.annotations));
  return val;
}

const _$AnnotationEnumMap = {
  Annotation.deprecated: 'deprecated',
  Annotation.sealed: 'sealed',
  Annotation.visibleForOverriding: 'visibleForOverriding',
  Annotation.visibleForTesting: 'visibleForTesting',
};

ExtensionShape _$ExtensionShapeFromJson(Map<String, dynamic> json) =>
    ExtensionShape(
      id: json['id'] as int,
      name: json['name'] as String,
      extendedClassId: json['extendedClassId'] as int,
      getters: (json['getters'] as List<dynamic>?)
              ?.map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      setters: (json['setters'] as List<dynamic>?)
              ?.map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      methods: (json['methods'] as List<dynamic>?)
              ?.map((e) => MethodShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      staticGetters: (json['staticGetters'] as List<dynamic>?)
              ?.map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      staticSetters: (json['staticSetters'] as List<dynamic>?)
              ?.map((e) => PropertyShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      staticMethods: (json['staticMethods'] as List<dynamic>?)
              ?.map((e) => MethodShape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      annotations: (json['annotations'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$AnnotationEnumMap, e))
              .toList() ??
          [],
    );

Map<String, dynamic> _$ExtensionShapeToJson(ExtensionShape instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'name': instance.name,
    'extendedClassId': instance.extendedClassId,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('getters', _listContentsOrNull(instance.getters));
  writeNotNull('setters', _listContentsOrNull(instance.setters));
  writeNotNull('methods', _listContentsOrNull(instance.methods));
  writeNotNull('staticGetters', _listContentsOrNull(instance.staticGetters));
  writeNotNull('staticSetters', _listContentsOrNull(instance.staticSetters));
  writeNotNull('staticMethods', _listContentsOrNull(instance.staticMethods));
  writeNotNull('annotations', _listAnnotationsOrNull(instance.annotations));
  return val;
}

MethodShape _$MethodShapeFromJson(Map<String, dynamic> json) => MethodShape(
      name: json['name'] as String,
    );

Map<String, dynamic> _$MethodShapeToJson(MethodShape instance) =>
    <String, dynamic>{
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

NamedConstructorShape _$NamedConstructorShapeFromJson(
        Map<String, dynamic> json) =>
    NamedConstructorShape(
      name: json['name'] as String,
    );

Map<String, dynamic> _$NamedConstructorShapeToJson(
        NamedConstructorShape instance) =>
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

TypedefShape _$TypedefShapeFromJson(Map<String, dynamic> json) => TypedefShape(
      id: json['id'] as int,
      name: json['name'] as String,
      targetClassId: json['targetClassId'] as int?,
    );

Map<String, dynamic> _$TypedefShapeToJson(TypedefShape instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'name': instance.name,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('targetClassId', instance.targetClassId);
  return val;
}
