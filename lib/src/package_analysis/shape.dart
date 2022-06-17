import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'shape.g.dart';

@sealed
@JsonSerializable()
class PackageShape {
  final List<LibraryShape> libraries;
  final List<ClassShape> classes;

  PackageShape({required this.libraries, required this.classes});

  factory PackageShape.fromJson(Map<String, dynamic> json) =>
      _$PackageShapeFromJson(json);

  Map<String, dynamic> toJson() => _$PackageShapeToJson(this);
}

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

  /// `Set` of [ClassShape.id] elements, where each one corresponds to a class
  /// exported in this library.
  final Set<int> exportedClasses;

  LibraryShape({required this.uri, required this.exportedClasses});

  factory LibraryShape.fromJson(Map<String, dynamic> json) =>
      _$LibraryShapeFromJson(json);

  Map<String, dynamic> toJson() => _$LibraryShapeToJson(this);
}

@sealed
@JsonSerializable()
class ClassShape {
  /// Unique identifier for this [ClassShape] within the given [PackageShape].
  ///
  /// Classes will be referenced using their [id] in other shapes, such as
  /// [LibraryShape].
  final int id;
  final String name;
  final List<MethodShape> methods;

  ClassShape({required this.id, required this.name, required this.methods});

  factory ClassShape.fromJson(Map<String, dynamic> json) =>
      _$ClassShapeFromJson(json);

  Map<String, dynamic> toJson() => _$ClassShapeToJson(this);
}

/// A Shape for describing a method belonging to a class.
@sealed
@JsonSerializable()
class MethodShape {
  final String name;

  MethodShape({required this.name});

  factory MethodShape.fromJson(Map<String, dynamic> json) =>
      _$MethodShapeFromJson(json);

  Map<String, dynamic> toJson() => _$MethodShapeToJson(this);
}
