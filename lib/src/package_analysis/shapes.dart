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

  PackageShape({
    required this.name,
    required this.version,
    required this.libraries,
    required this.getters,
    required this.setters,
    required this.functions,
    required this.classes,
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

  /// `List` of [PropertyShape.id] elements, where each one corresponds to a
  /// top-level getter exported in this library.
  final List<int> exportedGetters;

  /// `List` of [PropertyShape.id] elements, where each one corresponds to a
  /// top-level setter exported in this library.
  final List<int> exportedSetters;

  /// `List` of [MethodShape.id] elements, where each one corresponds to a
  /// top-level function exported in this library.
  final List<int> exportedFunctions;

  /// `List` of [ClassShape.id] elements, where each one corresponds to a class
  /// exported in this library.
  final List<int> exportedClasses;

  LibraryShape({
    required this.uri,
    required this.exportedGetters,
    required this.exportedSetters,
    required this.exportedFunctions,
    required this.exportedClasses,
  });

  factory LibraryShape.fromJson(Map<String, dynamic> json) =>
      _$LibraryShapeFromJson(json);

  Map<String, dynamic> toJson() => _$LibraryShapeToJson(this);
}

/// A Shape for describing a class.
@sealed
@JsonSerializable()
class ClassShape extends GlobalShapeBase {
  final List<PropertyShape> getters;
  final List<PropertyShape> setters;
  final List<MethodShape> methods;

  ClassShape({
    required super.id,
    required super.name,
    required this.getters,
    required this.setters,
    required this.methods,
  });

  factory ClassShape.fromJson(Map<String, dynamic> json) =>
      _$ClassShapeFromJson(json);

  Map<String, dynamic> toJson() => _$ClassShapeToJson(this);
}

/// A Shape for describing a class method
@sealed
@JsonSerializable()
class MethodShape {
  final String name;

  MethodShape({required this.name});

  factory MethodShape.fromJson(Map<String, dynamic> json) =>
      _$MethodShapeFromJson(json);

  Map<String, dynamic> toJson() => _$MethodShapeToJson(this);
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

/// A Shape for describing a getter/setter of a class property
@sealed
@JsonSerializable()
class PropertyShape {
  final String name;

  PropertyShape({required this.name});

  factory PropertyShape.fromJson(Map<String, dynamic> json) =>
      _$PropertyShapeFromJson(json);

  Map<String, dynamic> toJson() => _$PropertyShapeToJson(this);
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
