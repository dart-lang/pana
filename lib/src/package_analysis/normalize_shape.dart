import 'package:collection/collection.dart';

import 'shapes.dart';

/// Given a [PackageShape] create a new [PackageShape] structure where the
/// elements of [PackageShape.classes] are sorted canonically: first by
/// [ClassShape.name], then (if two classes share the same name) by a `String`
/// representation of the list of [LibraryShape.uri] objects corresponding to
/// the libraries from which the given class was exported. Their [ClassShape.id]
/// fields are re-assigned starting from 0, based on this ordering.
///
/// Because no two identically-named classes can be exported from the same
/// `List` of libraries (in fact, they can't both be exported from any one
/// library), this creates a deterministic mapping of ids to classes, for a
/// given input [PackageShape].
PackageShape normalizePackageShape(PackageShape package) {
  // map from a class id to a list of library uris where that class is exported
  final librariesWhereClassExported = <int, List<String>>{};

  // add key-value pair for every class that exists in the package
  for (final thisClass in package.classes) {
    librariesWhereClassExported[thisClass.id] = <String>[];
  }

  // populate the above-created list with library uris
  for (final library in package.libraries) {
    for (final classId in library.exportedClasses) {
      librariesWhereClassExported[classId]!.add(library.uri);
    }
  }

  // sort the above-populated lists and concatenate their entries, creating
  // another mapping
  final sortMapping = librariesWhereClassExported.map(
      (classId, libraryUris) => MapEntry(classId, libraryUris.sorted().join()));

  // sort the existing classes first by their id,
  // then (if the ids are equal) using [sortMapping]
  final classes = package.classes.sorted((a, b) {
    final compareIds = a.name.compareTo(b.name);
    if (compareIds != 0) {
      return compareIds;
    } else {
      return sortMapping[a.id]!.compareTo(sortMapping[b.id]!);
    }
  });

  // maps old ids to new ids
  final newIdMapping = <int, int>{};
  var newIdCounter = 0;

  // create new objects for the normalized PackageShape to be returned
  final newClasses = <ClassShape>{};
  final newLibraries = <LibraryShape>[];

  // create mapping and reassign ids in [classes] according to the sorted order
  for (final thisClass in classes) {
    newClasses.add(ClassShape(
      id: newIdCounter,
      name: thisClass.name,
      getters: thisClass.getters,
      setters: thisClass.setters,
      methods: thisClass.methods,
    ));
    newIdMapping[thisClass.id] = newIdCounter;
    newIdCounter += 1;
  }

  // reassign ids in [package.libraries]
  for (final library in package.libraries) {
    newLibraries.add(LibraryShape(
      uri: library.uri,
      getters: library.getters,
      setters: library.setters,
      functions: library.functions,
      exportedClasses: library.exportedClasses
          .map((classId) => newIdMapping[classId]!)
          .sorted(Comparable.compare)
          .toSet(),
    ));
  }

  return PackageShape(libraries: newLibraries, classes: newClasses);
}
