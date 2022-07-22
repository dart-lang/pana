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
    List<PropertyShape>? staticGetters,
    List<PropertyShape>? staticSetters,
    List<MethodShape>? staticMethods,
  }) =>
      ClassShape(
        id: id ?? this.id,
        name: name ?? this.name,
        getters: getters ?? this.getters,
        setters: setters ?? this.setters,
        methods: methods ?? this.methods,
        staticGetters: getters ?? this.staticGetters,
        staticSetters: setters ?? this.staticSetters,
        staticMethods: methods ?? this.staticMethods,
      );

  /// Modifies this [ClassShape] based on a list of others. The name and id of
  /// the original [ClassShape] is retained, and the other fields of type
  /// [List<T>] are expanded with the corresponding fields from the elements of
  /// [others].
  void add({required List<ClassShape> others}) {
    for (final otherClass in others) {
      getters.addAll(otherClass.getters);
      setters.addAll(otherClass.setters);
      methods.addAll(otherClass.methods);
      staticGetters.addAll(otherClass.staticGetters);
      staticSetters.addAll(otherClass.staticSetters);
      staticMethods.addAll(otherClass.staticMethods);
    }
  }
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

extension PackageShapeExt on PackageShape {
  /// Returns a list of the names of all the top-level functions which are defined in this package.
  List<String> get functionNames {
    return functions.map((function) => function.name).toList();
  }

  /// Returns a list of the names of all the class methods which are defined in this package.
  List<String> get methodNames {
    final methods = <String>[];
    for (final thisClass in classes) {
      methods.addAll(thisClass.methods.map((method) => method.name));
    }
    return methods;
  }
}
