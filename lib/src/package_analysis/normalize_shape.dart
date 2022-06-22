import 'package:collection/collection.dart';

import 'shapes.dart';

/// Given that the package has been analysed, sort the classes
/// deterministically (within a given input) and re-assign their ids based on
/// this order.
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
