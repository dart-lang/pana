import 'shapes.dart';

extension GlobalPropertyShapeExt on GlobalPropertyShape {
  /// Creates a new [GlobalPropertyShape] based on this one, but with some parts replaced.
  GlobalPropertyShape replace({
    int? id,
    String? name,
  }) =>
      GlobalPropertyShape(
        id: id ?? this.id,
        name: name ?? this.name,
      );
}


extension FunctionShapeExt on FunctionShape {
  /// Creates a new [FunctionShape] based on this one, but with some parts replaced.
  FunctionShape replace({
    int? id,
    String? name,
  }) =>
      FunctionShape(
        id: id ?? this.id,
        name: name ?? this.name,
      );
}

extension ClassShapeExt on ClassShape {
  /// Creates a new [ClassShape] based on this one, but with some parts replaced.
  ClassShape replace({
    int? id,
    String? name,
    List<PropertyShape>? getters,
    List<PropertyShape>? setters,
    List<MethodShape>? methods,
  }) =>
      ClassShape(
        id: id ?? this.id,
        name: name ?? this.name,
        getters: getters ?? this.getters,
        setters: setters ?? this.setters,
        methods: methods ?? this.methods,
      );
}

extension LibraryShapeExt on LibraryShape {
  /// Creates a new [LibraryShape] based on this one, but with some parts replaced.
  LibraryShape replace({
    String? uri,
    List<int>? exportedGetters,
    List<int>? exportedSetters,
    List<int>? exportedFunctions,
    List<int>? exportedClasses,
  }) =>
      LibraryShape(
        uri: uri ?? this.uri,
        exportedGetters: exportedGetters ?? this.exportedGetters,
        exportedSetters: exportedSetters ?? this.exportedSetters,
        exportedFunctions: exportedFunctions ?? this.exportedFunctions,
        exportedClasses: exportedClasses ?? this.exportedClasses,
      );
}
