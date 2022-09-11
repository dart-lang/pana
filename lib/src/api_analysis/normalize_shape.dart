// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

import 'shapes.dart';
import 'shapes_ext.dart';

/// Given a [PackageShape] create a new [PackageShape] structure where the
/// elements of [PackageShape.getters], [PackageShape.setters],
/// [PackageShape.functions], [PackageShape.classes] and [PackageShape.typedefs]
/// are sorted canonically: first by their `name`, then (if two `Shape`s share
/// the same name) by a `String` representation of the list of
/// [LibraryShape.uri] objects corresponding to the libraries from which the
/// given `Shape` was exported. The `id` fields of every `Shape` are re-assigned
/// starting from 0, based on this ordering.
///
/// Because no two identically-named `Shape`s of the same kind can be exported
/// from the same `List` of libraries (in fact, they can't both be exported from
/// any one library), this creates a deterministic mapping of ids to `Shape`s,
/// for a given input [PackageShape].
PackageShape normalizePackageShape(PackageShape package) {
  // Maps from a Shape id to a list of library uris where that Shape is exported.
  final librariesWhereShapeExported = <int, List<String>>{};

  // Add key-value pair for every top-level Shape that exists in the package.
  for (final shape in [
    ...package.getters,
    ...package.setters,
    ...package.functions,
    ...package.classes,
    ...package.extensions,
    ...package.typedefs,
  ]) {
    librariesWhereShapeExported[shape.id] = <String>[];
  }

  // Populate the above-created [List]s with library uris.
  for (final library in package.libraries) {
    for (final shapeId in [
      ...library.exportedSetters,
      ...library.exportedGetters,
      ...library.exportedFunctions,
      ...library.exportedExtensions,
      ...library.exportedClasses,
      ...library.exportedTypedefs,
    ]) {
      librariesWhereShapeExported[shapeId]!.add(library.uri);
    }
  }

  // Sort the above-populated lists and concatenate their entries, creating
  // another mapping.
  final sortMapping = librariesWhereShapeExported.map(
      (shapeId, libraryUris) => MapEntry(shapeId, libraryUris.sorted().join()));

  final oldIdToNewId = <int, int>{};
  var newIdCounter = 0;

  // Compares Shapes first using their name, then (if the names are equal) using
  // [sortMapping].
  int compareShape(GlobalShapeBase a, GlobalShapeBase b) {
    final compareIds = a.name.compareTo(b.name);
    if (compareIds != 0) {
      return compareIds;
    } else {
      return sortMapping[a.id]!.compareTo(sortMapping[b.id]!);
    }
  }

  // Create mapping for ids and reassign them according to the sorted order.
  final newGetters = package.getters.sorted(compareShape).map((getter) {
    oldIdToNewId[getter.id] = newIdCounter;
    return getter.withId(newIdCounter++);
  }).toList();
  final newSetters = package.setters.sorted(compareShape).map((setter) {
    oldIdToNewId[setter.id] = newIdCounter;
    return setter.withId(newIdCounter++);
  }).toList();
  final newFunctions = package.functions.sorted(compareShape).map((function) {
    oldIdToNewId[function.id] = newIdCounter;
    return function.withId(newIdCounter++);
  }).toList();
  final newClasses = package.classes.sorted(compareShape).map((thisClass) {
    oldIdToNewId[thisClass.id] = newIdCounter;
    return thisClass.withId(newIdCounter++);
  }).toList();
  final newTypedefs = package.typedefs.sorted(compareShape).map((thisTypedef) {
    oldIdToNewId[thisTypedef.id] = newIdCounter;
    return thisTypedef.withIds(
      newId: newIdCounter++,
      newTargetId: thisTypedef.targetClassId == null
          ? null
          : oldIdToNewId[thisTypedef.targetClassId]!,
    );
  }).toList();
  final newExtensions =
      package.extensions.sorted(compareShape).map((thisExtension) {
    oldIdToNewId[thisExtension.id] = newIdCounter;
    return thisExtension.withIds(
      newId: newIdCounter++,
      newExtendedClassId: oldIdToNewId[thisExtension.extendedClassId]!,
    );
  }).toList();

  List<int> reassignIds(List<int> oldIds) {
    return oldIds
        .map((classId) => oldIdToNewId[classId]!)
        .sorted(Comparable.compare);
  }

  // Reassign ids in [package.libraries].
  final newLibraries = package.libraries
      .map((library) => library.replaceAll(
            exportedGetters: reassignIds(library.exportedGetters),
            exportedSetters: reassignIds(library.exportedSetters),
            exportedFunctions: reassignIds(library.exportedFunctions),
            exportedClasses: reassignIds(library.exportedClasses),
            exportedTypedefs: reassignIds(library.exportedTypedefs),
            exportedExtensions: reassignIds(library.exportedExtensions),
          ))
      .toList();

  // Sort all the properties of type List<T> in all the classes and extensions,
  // apart from annotations which already have a canonical order.
  for (final thisClass in newClasses) {
    for (final classMemberList in [
      thisClass.getters,
      thisClass.setters,
      thisClass.methods,
      thisClass.staticGetters,
      thisClass.staticSetters,
      thisClass.staticMethods,
      thisClass.namedConstructors,
    ]) {
      classMemberList.sort((ClassMemberShapeBase a, ClassMemberShapeBase b) =>
          a.name.compareTo(b.name));
    }
  }
  for (final thisExtension in newExtensions) {
    for (final extensionMemberList in [
      thisExtension.getters,
      thisExtension.setters,
      thisExtension.methods,
      thisExtension.staticGetters,
      thisExtension.staticSetters,
      thisExtension.staticMethods,
    ]) {
      extensionMemberList.sort(
          (ClassMemberShapeBase a, ClassMemberShapeBase b) =>
              a.name.compareTo(b.name));
    }
  }

  return PackageShape(
    name: package.name,
    version: package.version,
    libraries: newLibraries,
    getters: newGetters,
    setters: newSetters,
    functions: newFunctions,
    classes: newClasses,
    typedefs: newTypedefs,
    extensions: newExtensions,
  );
}
