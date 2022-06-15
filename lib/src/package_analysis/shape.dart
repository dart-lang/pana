import 'package:json_annotation/json_annotation.dart';

part 'shape.g.dart';

@JsonSerializable()
class PackageShape {
  final List<LibraryShape> libraries;

  PackageShape(this.libraries);

  factory PackageShape.fromJson(Map<String, dynamic> json) =>
      _$PackageShapeFromJson(json);

  Map<String, dynamic> toJson() => _$PackageShapeToJson(this);
}

@JsonSerializable()
class LibraryShape {
  @JsonKey(name: 'file-path')
  final String filePath;
  final List<ClassShape> classes;

  LibraryShape(this.filePath, this.classes);

  factory LibraryShape.fromJson(Map<String, dynamic> json) =>
      _$LibraryShapeFromJson(json);

  Map<String, dynamic> toJson() => _$LibraryShapeToJson(this);
}

@JsonSerializable()
class ClassShape {
  // TODO: to be used later for classes which reference other classes
  // final int id;
  // final List<String> exportedFrom;
  final String name;
  final List<MethodShape> methods;

  //Map<String, MethodShape> get methods => {for (var method in _methods) method.name: method};

  ClassShape(this.name, this.methods);

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
