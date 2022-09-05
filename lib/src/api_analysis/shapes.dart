// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'shapes.g.dart';

/// A Shape for describing a package.
@sealed
@JsonSerializable()
class PackageShape {
  /// The package name.
  final String name;

  /// The package version.
  final String version;

  /// All public libraries of this package.
  final List<LibraryShape> libraries;

  /// All top-level getters exported somewhere in this package.
  final List<GlobalPropertyShape> getters;

  /// All top-level setters exported somewhere in this package.
  final List<GlobalPropertyShape> setters;

  /// All top-level functions exported somewhere in this package.
  final List<FunctionShape> functions;

  /// All classes exported somewhere in this package.
  final List<ClassShape> classes;

  /// All extensions exported somewhere in this package.
  final List<ExtensionShape> extensions;

  /// All typedefs exported somewhere in this package.
  final List<TypedefShape> typedefs;

  PackageShape({
    required this.name,
    required this.version,
    required this.libraries,
    required this.getters,
    required this.setters,
    required this.functions,
    required this.classes,
    required this.extensions,
    required this.typedefs,
  });

  factory PackageShape.fromJson(Map<String, dynamic> json) =>
      _$PackageShapeFromJson(json);

  Map<String, dynamic> toJson() => _$PackageShapeToJson(this);
}

/// A Shape for describing a library, which may consist of multiple parts.
@sealed
@JsonSerializable()
class LibraryShape {
  /// Unique identifier for the library represented by this [LibraryShape]
  /// within the given [PackageShape]. This uses the syntax beginning with
  /// `package:` which would usually be used for importing this library.
  ///
  /// Example:
  /// ```
  /// package:my_package/my_library.dart
  /// ```
  final String uri;

  /// `List` of `GlobalPropertyShape.id` elements, where each one corresponds to a
  /// top-level getter exported in this library.
  final List<int> exportedGetters;

  /// `List` of `GlobalPropertyShape.id` elements, where each one corresponds to a
  /// top-level setter exported in this library.
  final List<int> exportedSetters;

  /// `List` of `FunctionShape.id` elements, where each one corresponds to a
  /// top-level function exported in this library.
  final List<int> exportedFunctions;

  /// `List` of `ClassShape.id` elements, where each one corresponds to a class
  /// exported in this library.
  final List<int> exportedClasses;

  /// `List` of `ExtensionShape.id` elements, where each one corresponds to an
  /// extension exported in this library.
  final List<int> exportedExtensions;

  /// `List` of `TypedefShape.id` elements, where each one corresponds to a
  /// typedef exported in this library.
  final List<int> exportedTypedefs;

  LibraryShape({
    required this.uri,
    required this.exportedGetters,
    required this.exportedSetters,
    required this.exportedFunctions,
    required this.exportedClasses,
    required this.exportedExtensions,
    required this.exportedTypedefs,
  });

  factory LibraryShape.fromJson(Map<String, dynamic> json) =>
      _$LibraryShapeFromJson(json);

  Map<String, dynamic> toJson() => _$LibraryShapeToJson(this);
}

/// A Shape for describing a class.
/// Any type parameters are ignored/omitted in the class name.
@sealed
@JsonSerializable()
class ClassShape extends GlobalShapeBase {
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<PropertyShape> getters;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<PropertyShape> setters;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<MethodShape> methods;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<PropertyShape> staticGetters;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<PropertyShape> staticSetters;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<MethodShape> staticMethods;
  final bool unnamedConstructor;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<NamedConstructorShape> namedConstructors;
  @JsonKey(
      includeIfNull: false, toJson: _listAnnotationsOrNull, defaultValue: [])
  final List<Annotation> annotations;

  ClassShape({
    required super.id,
    required super.name,
    required this.getters,
    required this.setters,
    required this.methods,
    required this.staticGetters,
    required this.staticSetters,
    required this.staticMethods,
    required this.unnamedConstructor,
    required this.namedConstructors,
    required this.annotations,
  });

  factory ClassShape.fromJson(Map<String, dynamic> json) =>
      _$ClassShapeFromJson(json);

  Map<String, dynamic> toJson() => _$ClassShapeToJson(this);
}

/// A Shape for describing an extension.
/// Any type parameters are ignored/omitted in the extension name.
@sealed
@JsonSerializable()
class ExtensionShape extends GlobalShapeBase {
  final int extendedClassId;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<PropertyShape> getters;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<PropertyShape> setters;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<MethodShape> methods;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<PropertyShape> staticGetters;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<PropertyShape> staticSetters;
  @JsonKey(includeIfNull: false, toJson: _listContentsOrNull, defaultValue: [])
  final List<MethodShape> staticMethods;
  @JsonKey(
      includeIfNull: false, toJson: _listAnnotationsOrNull, defaultValue: [])
  final List<Annotation> annotations;

  ExtensionShape({
    required super.id,
    required super.name,
    required this.extendedClassId,
    required this.getters,
    required this.setters,
    required this.methods,
    required this.staticGetters,
    required this.staticSetters,
    required this.staticMethods,
    required this.annotations,
  });

  factory ExtensionShape.fromJson(Map<String, dynamic> json) =>
      _$ExtensionShapeFromJson(json);

  Map<String, dynamic> toJson() => _$ExtensionShapeToJson(this);
}

/// A Shape for describing a class/extension method.
@sealed
@JsonSerializable()
class MethodShape extends ClassMemberShapeBase {
  MethodShape({required super.name});

  factory MethodShape.fromJson(Map<String, dynamic> json) =>
      _$MethodShapeFromJson(json);

  Map<String, dynamic> toJson() => _$MethodShapeToJson(this);
}

/// A Shape for describing a getter/setter of a class/extension property.
@sealed
@JsonSerializable()
class PropertyShape extends ClassMemberShapeBase {
  PropertyShape({required super.name});

  factory PropertyShape.fromJson(Map<String, dynamic> json) =>
      _$PropertyShapeFromJson(json);

  Map<String, dynamic> toJson() => _$PropertyShapeToJson(this);
}

/// A Shape for describing a named constructor of a class.
@sealed
@JsonSerializable()
class NamedConstructorShape extends ClassMemberShapeBase {
  NamedConstructorShape({required super.name});

  factory NamedConstructorShape.fromJson(Map<String, dynamic> json) =>
      _$NamedConstructorShapeFromJson(json);

  Map<String, dynamic> toJson() => _$NamedConstructorShapeToJson(this);
}

/// A Shape for describing a top-level function
@sealed
@JsonSerializable()
class FunctionShape extends GlobalShapeBase {
  FunctionShape({required super.id, required super.name});

  factory FunctionShape.fromJson(Map<String, dynamic> json) =>
      _$FunctionShapeFromJson(json);

  Map<String, dynamic> toJson() => _$FunctionShapeToJson(this);
}

/// A Shape for describing a getter/setter of a top-level variable
@sealed
@JsonSerializable()
class GlobalPropertyShape extends GlobalShapeBase {
  GlobalPropertyShape({required super.id, required super.name});

  factory GlobalPropertyShape.fromJson(Map<String, dynamic> json) =>
      _$GlobalPropertyShapeFromJson(json);

  Map<String, dynamic> toJson() => _$GlobalPropertyShapeToJson(this);
}

/// A Shape for describing a typedef.
/// Any type parameters are ignored/omitted in the alias name.
@sealed
@JsonSerializable()
class TypedefShape extends GlobalShapeBase {
  /// The `ClassShape.id` that this typedef points to, or null if defined as function type
  final int? targetClassId;

  TypedefShape(
      {required super.id, required super.name, required this.targetClassId});

  factory TypedefShape.fromJson(Map<String, dynamic> json) =>
      _$TypedefShapeFromJson(json);

  Map<String, dynamic> toJson() => _$TypedefShapeToJson(this);
}

enum Annotation {
  deprecated,
  sealed,
  visibleForOverriding,
  visibleForTesting,
}

@internal
abstract class GlobalShapeBase {
  final int id;
  final String name;

  GlobalShapeBase({required this.id, required this.name});

  @override
  bool operator ==(other) => other is GlobalShapeBase && id == other.id;

  @override
  int get hashCode => id;
}

@internal
abstract class ClassMemberShapeBase {
  final String name;

  ClassMemberShapeBase({required this.name});
}

List? _listContentsOrNull(List a) =>
    a.isEmpty ? null : a.map((e) => e.toJson()).toList();

List<String>? _listAnnotationsOrNull(List<Annotation> a) =>
    a.isEmpty ? null : a.map((e) => e.name).toList();
