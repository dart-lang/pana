// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'shapes.dart';

extension GlobalPropertyShapeExt on GlobalPropertyShape {
  /// Creates a new [GlobalPropertyShape] based on this one, but with the id replaced.
  GlobalPropertyShape replaceWithNewId(int newId) => GlobalPropertyShape(
        id: newId,
        name: name,
      );
}

extension FunctionShapeExt on FunctionShape {
  /// Creates a new [FunctionShape] based on this one, but with the id replaced.
  FunctionShape replaceWithNewId(int newId) => FunctionShape(
        id: newId,
        name: name,
      );
}

extension TypedefShapeExt on TypedefShape {
  /// Creates a new [TypedefShape] based on this one, but with the id and targetClassId replaced.
  TypedefShape replaceWithNewIds({
    required int newId,
    required int? newTargetId,
  }) =>
      TypedefShape(
        id: newId,
        name: name,
        targetClassId: newTargetId,
      );
}

extension ExtensionShapeExt on ExtensionShape {
  /// Creates a new [ExtensionShape] based on this one, but with the id and extendedClassId replaced.
  ExtensionShape replaceWithNewIds({
    required int newId,
    required int newExtendedClassId,
  }) =>
      ExtensionShape(
        id: newId,
        name: name,
        extendedClassId: newExtendedClassId,
        getters: getters,
        setters: setters,
        methods: methods,
        staticGetters: staticGetters,
        staticSetters: staticSetters,
        staticMethods: staticMethods,
        annotations: annotations,
      );
}

extension ClassShapeExt on ClassShape {
  /// Creates a new [ClassShape] based on this one, but with the id replaced.
  ClassShape replaceWithNewId(int newId) => ClassShape(
        id: newId,
        name: name,
        getters: getters,
        setters: setters,
        methods: methods,
        staticGetters: staticGetters,
        staticSetters: staticSetters,
        staticMethods: staticMethods,
        unnamedConstructor: unnamedConstructor,
        namedConstructors: namedConstructors,
        annotations: annotations,
      );

  /// Modifies this [ClassShape] based on a list of others. The `name`, `id`,
  /// `unnamedConstructor`, `namedConstructors` and `annotations` of the
  /// original [ClassShape] are retained (subclasses don’t inherit constructors
  /// or annotations from their superclass), and the other fields of type
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
  /// Creates a new [LibraryShape] based on this one, but with all the parts
  /// (except `uri`) replaced.
  LibraryShape replaceAll({
    required List<int> exportedGetters,
    required List<int> exportedSetters,
    required List<int> exportedFunctions,
    required List<int> exportedClasses,
    required List<int> exportedExtensions,
    required List<int> exportedTypedefs,
  }) =>
      LibraryShape(
        uri: uri,
        exportedGetters: exportedGetters,
        exportedSetters: exportedSetters,
        exportedFunctions: exportedFunctions,
        exportedClasses: exportedClasses,
        exportedExtensions: exportedExtensions,
        exportedTypedefs: exportedTypedefs,
      );
}

extension PackageShapeExt on PackageShape {
  /// Does this package have a function named [name]?
  bool containsFunctionWithName(String name) =>
      functions.map((function) => function.name).contains(name);

  /// Returns an [Iterable<ClassShape>] corresponding to the classes which can
  /// be accessed by the name [name], whether that is their name, or the name of
  /// a typedef which points to the class.
  Iterable<ClassShape> classesMatchingName(String name) {
    // either the name of the class has to match, or there must exist a typedef
    // with a matching name and a target id which matches that of the class
    return classes.where((thisClass) =>
        thisClass.name == name ||
        typedefs.any((thisTypedef) =>
            thisTypedef.name == name &&
            thisClass.id == thisTypedef.targetClassId));
  }

  /// Does this package have a class (or a typedef pointing to a class) named
  /// [className] with a method (static or not) named [name]?
  bool containsMethodWithName(String className, String name) {
    for (final thisClass in classesMatchingName(className)) {
      if ([...thisClass.methods, ...thisClass.staticMethods]
          .any((method) => method.name == name)) {
        return true;
      }
    }
    return false;
  }

  /// Does this package have a class (or a typedef pointing to a class) named
  /// [className] with a property (static or not, getter or setter) named [name]?
  bool containsPropertyWithName(String className, String name) =>
      containsGetterWithName(className, name) ||
      containsSetterWithName(className, name);

  /// Does this package have a class (or a typedef pointing to a class) named
  /// [className] with a getter (static or not) named [name]?
  bool containsGetterWithName(String className, String name) {
    for (final thisClass in classesMatchingName(className)) {
      if ([...thisClass.getters, ...thisClass.staticGetters]
          .any((property) => property.name == name)) {
        return true;
      }
    }
    return false;
  }

  /// Does this package have a class (or a typedef pointing to a class) named
  /// [className] with a setter (static or not) named [name]?
  bool containsSetterWithName(String className, String name) {
    for (final thisClass in classesMatchingName(className)) {
      if ([...thisClass.setters, ...thisClass.staticSetters]
          .any((property) => property.name == name)) {
        return true;
      }
    }
    return false;
  }

  /// Returns an [Iterable<ExtensionShape>] corresponding to the extensions
  /// named [name].
  Iterable<ExtensionShape> extensionsMatchingName(String name) =>
      extensions.where((thisExtension) => thisExtension.name == name);

  /// Does this package have an extension named [extensionName] with a method
  /// (static or not) named [name]?
  bool containsExtensionMethodWithName(String extensionName, String name) {
    for (final thisExtension in extensionsMatchingName(extensionName)) {
      if ([...thisExtension.methods, ...thisExtension.staticMethods]
          .any((method) => method.name == name)) {
        return true;
      }
    }
    return false;
  }

  /// Does this package have an extension named [extensionName] with a property
  /// (static or not, getter or setter) named [name]?
  bool containsExtensionPropertyWithName(String extensionName, String name) =>
      containsExtensionGetterWithName(extensionName, name) ||
      containsExtensionSetterWithName(extensionName, name);

  /// Does this package have an extension named [extensionName] with a getter
  /// (static or not) named [name]?
  bool containsExtensionGetterWithName(String extensionName, String name) {
    for (final thisExtension in extensionsMatchingName(extensionName)) {
      if ([...thisExtension.getters, ...thisExtension.staticGetters]
          .any((property) => property.name == name)) {
        return true;
      }
    }
    return false;
  }

  /// Does this package have an extension named [extensionName] with a setter
  /// (static or not) named [name]?
  bool containsExtensionSetterWithName(String extensionName, String name) {
    for (final thisExtension in extensionsMatchingName(extensionName)) {
      if ([...thisExtension.setters, ...thisExtension.staticSetters]
          .any((property) => property.name == name)) {
        return true;
      }
    }
    return false;
  }
}
