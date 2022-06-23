import 'shapes.dart';

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
    List<PropertyShape>? getters,
    List<PropertyShape>? setters,
    List<MethodShape>? functions,
    Set<int>? exportedClasses,
  }) =>
      LibraryShape(
        uri: uri ?? this.uri,
        getters: getters ?? this.getters,
        setters: setters ?? this.setters,
        functions: functions ?? this.functions,
        exportedClasses: exportedClasses ?? this.exportedClasses,
      );
}
