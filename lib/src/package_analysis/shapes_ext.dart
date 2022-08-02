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
  /// [others], only where the addition of elements of the field [List]s does
  /// not cause result in duplicate class members.
  void add({required List<ClassShape> others}) {
    /// Adds elements of [other] to [list] without creating duplicates.
    void addWithoutDuplicates(
      List<ClassMemberShapeBase> list,
      List<ClassMemberShapeBase> other,
    ) {
      list.addAll(other.where((otherMember) => !list
          .any((existingMember) => existingMember.name == otherMember.name)));
    }

    for (final otherClass in others) {
      addWithoutDuplicates(getters, otherClass.getters);
      addWithoutDuplicates(setters, otherClass.setters);
      addWithoutDuplicates(methods, otherClass.methods);
      addWithoutDuplicates(staticGetters, otherClass.staticGetters);
      addWithoutDuplicates(staticSetters, otherClass.staticSetters);
      addWithoutDuplicates(staticMethods, otherClass.staticMethods);
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
  /// Does this package have a function named [name]?
  bool containsFunctionWithName(String name) =>
      functions.map((function) => function.name).contains(name);

  /// Does this package have a class named [className] with a method (static or not) named [name]?
  bool containsMethodWithName(String className, String name) {
    final classesMatchingName =
        classes.where((thisClass) => thisClass.name == className);
    for (final thisClass in classesMatchingName) {
      if ([...thisClass.methods, ...thisClass.staticMethods]
          .any((method) => method.name == name)) {
        return true;
      }
    }
    return false;
  }

  /// Does this package have a class named [className] with a property (static or not, getter or setter) named [name]?
  bool containsPropertyWithName(String className, String name) =>
      containsGetterWithName(className, name) ||
      containsSetterWithName(className, name);

  /// Does this package have a class named [className] with a getter (static or not) named [name]?
  bool containsGetterWithName(String className, String name) {
    final classesMatchingName =
        classes.where((thisClass) => thisClass.name == className);
    for (final thisClass in classesMatchingName) {
      if ([
        ...thisClass.getters,
        ...thisClass.staticGetters,
      ].any((property) => property.name == name)) {
        return true;
      }
    }
    return false;
  }

  /// Does this package have a class named [className] with a setter (static or not) named [name]?
  bool containsSetterWithName(String className, String name) {
    final classesMatchingName =
        classes.where((thisClass) => thisClass.name == className);
    for (final thisClass in classesMatchingName) {
      if ([
        ...thisClass.setters,
        ...thisClass.staticSetters,
      ].any((property) => property.name == name)) {
        return true;
      }
    }
    return false;
  }
}
