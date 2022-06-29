import 'package:collection/collection.dart';

import 'shapes.dart';
import 'shapes_ext.dart';

/// Given a [PackageShape] create a new [PackageShape] structure where the
/// elements of [PackageShape.getters], [PackageShape.setters],
/// [PackageShape.functions] and [PackageShape.classes] are sorted canonically:
/// first by their `name`, then (if two `Shape`s share the same name) by a
/// `String` representation of the list of [LibraryShape.uri] objects
/// corresponding to the libraries from which the given `Shape` was exported.
/// The `id` fields of every `Shape` are re-assigned starting from 0, based on
/// this ordering.
///
/// Because no two identically-named `Shape`s of the same kind can be exported
/// from the same `List` of libraries (in fact, they can't both be exported from
/// any one library), this creates a deterministic mapping of ids to `Shape`s,
/// for a given input [PackageShape].
PackageShape normalizePackageShape(PackageShape package) {
  // map from a Shape id to a list of library uris where that Shape is exported
  final librariesWhereShapeExported = <int, List<String>>{};

  // add key-value pair for every Shape that exists in the package
  for (final shape in [
    ...package.getters,
    ...package.setters,
    ...package.functions,
    ...package.classes,
  ]) {
    librariesWhereShapeExported[shape.id] = <String>[];
  }

  // populate the above-created list with library uris
  for (final library in package.libraries) {
    for (final shapeId in [
      ...library.exportedSetters,
      ...library.exportedGetters,
      ...library.exportedFunctions,
      ...library.exportedClasses,
    ]) {
      librariesWhereShapeExported[shapeId]!.add(library.uri);
    }
  }

  // sort the above-populated lists and concatenate their entries, creating
  // another mapping
  final sortMapping = librariesWhereShapeExported.map(
      (shapeId, libraryUris) => MapEntry(shapeId, libraryUris.sorted().join()));

  final oldIdToNewId = <int, int>{};
  var newIdCounter = 0;

  // compares Shapes first using their name,
  // then (if the names are equal) using [sortMapping]
  int compareShape(GlobalShapeBase a, GlobalShapeBase b) {
    final compareIds = a.name.compareTo(b.name);
    if (compareIds != 0) {
      return compareIds;
    } else {
      return sortMapping[a.id]!.compareTo(sortMapping[b.id]!);
    }
  }

  // create mapping for ids and reassign them according to the sorted order
  final newGetters = package.getters.sorted(compareShape).map((getter) {
    oldIdToNewId[getter.id] = newIdCounter;
    return getter.replace(id: newIdCounter++);
  }).toList();
  final newSetters = package.setters.sorted(compareShape).map((setter) {
    oldIdToNewId[setter.id] = newIdCounter;
    return setter.replace(id: newIdCounter++);
  }).toList();
  final newFunctions = package.functions.sorted(compareShape).map((function) {
    oldIdToNewId[function.id] = newIdCounter;
    return function.replace(id: newIdCounter++);
  }).toList();
  final newClasses = package.classes.sorted(compareShape).map((thisClass) {
    oldIdToNewId[thisClass.id] = newIdCounter;
    return thisClass.replace(id: newIdCounter++);
  }).toList();

  List<int> reassignIds(List<int> oldIds) {
    return oldIds
        .map((classId) => oldIdToNewId[classId]!)
        .sorted(Comparable.compare);
  }

  // reassign ids in [package.libraries]
  final newLibraries = package.libraries
      .map((library) => library.replace(
            exportedGetters: reassignIds(library.exportedGetters),
            exportedSetters: reassignIds(library.exportedSetters),
            exportedFunctions: reassignIds(library.exportedFunctions),
            exportedClasses: reassignIds(library.exportedClasses),
          ))
      .toList();

  return PackageShape(
    libraries: newLibraries,
    getters: newGetters,
    setters: newSetters,
    functions: newFunctions,
    classes: newClasses,
  );
}
