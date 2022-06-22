import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'shapes.g.dart';

/// A Shape for describing a package.
@sealed
@JsonSerializable()
class PackageShape {
  final List<LibraryShape> libraries;

  /// All the classes defined in the libraries of this package.
  final Set<ClassShape> classes;

  PackageShape({required this.libraries, required this.classes});

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

  final List<PropertyShape> getters;
  final List<PropertyShape> setters;

  /// The top-level functions exported in this library.
  final List<MethodShape> functions;

  /// `Set` of [ClassShape.id] elements, where each one corresponds to a class
  /// exported in this library.
  final Set<int> exportedClasses;

  LibraryShape({
    required this.uri,
    required this.getters,
    required this.setters,
    required this.functions,
    required this.exportedClasses,
  });

  factory LibraryShape.fromJson(Map<String, dynamic> json) =>
      _$LibraryShapeFromJson(json);

  Map<String, dynamic> toJson() => _$LibraryShapeToJson(this);
}

/// A Shape for describing a class.
@sealed
@JsonSerializable()
class ClassShape {
  /// Unique identifier for this [ClassShape] within the given [PackageShape].
  ///
  /// Classes will be referenced using their [id] in other shapes, such as
  /// [LibraryShape].
  final int id;
  final String name;
  final List<PropertyShape> getters;
  final List<PropertyShape> setters;
  final List<MethodShape> methods;

  ClassShape({
    required this.id,
    required this.name,
    required this.getters,
    required this.setters,
    required this.methods,
  });

  @override
  bool operator ==(other) => other is ClassShape && id == other.id;

  @override
  int get hashCode => id;

  factory ClassShape.fromJson(Map<String, dynamic> json) =>
      _$ClassShapeFromJson(json);

  Map<String, dynamic> toJson() => _$ClassShapeToJson(this);
}

/// A Shape for describing a class method or a top-level function.
@sealed
@JsonSerializable()
class MethodShape {
  final String name;

  MethodShape({required this.name});

  factory MethodShape.fromJson(Map<String, dynamic> json) =>
      _$MethodShapeFromJson(json);

  Map<String, dynamic> toJson() => _$MethodShapeToJson(this);
}

/// A Shape for describing a getter/setter of a class property or a top-level
/// variable.
@sealed
@JsonSerializable()
class PropertyShape {
  final String name;

  PropertyShape({required this.name});

  factory PropertyShape.fromJson(Map<String, dynamic> json) =>
      _$PropertyShapeFromJson(json);

  Map<String, dynamic> toJson() => _$PropertyShapeToJson(this);
}
