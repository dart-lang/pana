import 'package:json_annotation/json_annotation.dart';

part 'shape.g.dart';

@JsonSerializable()
class PackageShape {
  final List<LibraryShape> libraries;
  final List<ClassShape> classes;

  PackageShape(this.libraries, this.classes);

  factory PackageShape.fromJson(Map<String, dynamic> json) =>
      _$PackageShapeFromJson(json);

  Map<String, dynamic> toJson() => _$PackageShapeToJson(this);
}

@JsonSerializable()
class LibraryShape {
  final String identifier;
  @JsonKey(name: 'exported-classes')
  final Set<int> exportedClasses;

  LibraryShape(this.identifier, this.exportedClasses);

  factory LibraryShape.fromJson(Map<String, dynamic> json) =>
      _$LibraryShapeFromJson(json);

  Map<String, dynamic> toJson() => _$LibraryShapeToJson(this);
}

@JsonSerializable()
class ClassShape {
  final int id;
  final String name;
  final List<MethodShape> methods;

  ClassShape(this.id, this.name, this.methods);

  factory ClassShape.fromJson(Map<String, dynamic> json) =>
      _$ClassShapeFromJson(json);

  Map<String, dynamic> toJson() => _$ClassShapeToJson(this);
}

@JsonSerializable()
class MethodShape {
  final String name;

  MethodShape(this.name);

  factory MethodShape.fromJson(Map<String, dynamic> json) =>
      _$MethodShapeFromJson(json);

  Map<String, dynamic> toJson() => _$MethodShapeToJson(this);
}
