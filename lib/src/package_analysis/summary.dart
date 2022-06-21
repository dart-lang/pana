import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:pana/src/package_analysis/shape.dart';
import 'package:path/path.dart' as path;

import 'common.dart';

Future<PackageShape> summarizePackage(
  PackageAnalysisContext packageAnalysisContext,
  String packageLocation,
) async {
  final package =
      PackageShape(libraries: <LibraryShape>[], classes: <ClassShape>[]);

  /// Ids of classes defined in a given library
  final classDefinitions = <String, Set<int>>{};

  /// Identifiers of libraries exported in a given library
  final libraryExports = <String, List<String>>{};

  /// Ids of classes exported in a given library
  final classExports = <String, Set<int>>{};

  MethodShape summarizeExecutableElement(ExecutableElement executableElement) {
    // ExecutableElement is a superclass of both MethodShape and FunctionShape
    return MethodShape(name: executableElement.name);
  }

  PropertyShape summarizeProperty(PropertyAccessorElement property) {
    return PropertyShape(name: property.variable.name);
  }

  ClassShape summarizeClassElement(ClassElement classElement) {
    final methods = classElement.methods
        .where((element) => element.isPublic)
        .map(summarizeExecutableElement)
        .toList();

    // an accessor is a getter or a setter
    final accessors = classElement.accessors;

    final getters = accessors
        .where((element) => element.isGetter)
        .map(summarizeProperty)
        .toList();

    final setters = accessors
        .where((element) => element.isSetter)
        .map(summarizeProperty)
        .toList();

    return ClassShape(
        id: classElement.id,
        name: classElement.name,
        methods: methods,
        getters: getters,
        setters: setters);
  }

  void summarizeLibraryElement(
      LibraryElement libraryElement, String libraryPath) {
    final identifier = libraryElement.identifier;

    final publicTopLevelElements = libraryElement.topLevelElements
        .where((element) => element.isPublic)
        .toList();

    // classes defined in this library
    final classes = publicTopLevelElements
        .whereType<ClassElement>()
        .map(summarizeClassElement)
        .toList();
    final classIds = classes.map((thisClass) => thisClass.id).toSet();

    final getters = publicTopLevelElements
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isGetter)
        .map(summarizeProperty)
        .toList();

    final setters = publicTopLevelElements
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isSetter)
        .map(summarizeProperty)
        .toList();

    final functions = publicTopLevelElements
        .whereType<FunctionElement>()
        .map(summarizeExecutableElement)
        .toList();

    package.classes.addAll(classes);
    package.libraries.add(LibraryShape(
        uri: identifier,
        exportedClasses: <int>{},
        getters: getters,
        setters: setters,
        functions: functions));

    classDefinitions[identifier] = classIds;
    libraryExports[identifier] = libraryElement.exportedLibraries
        .map((library) => library.identifier)
        .toList();
  }

  /// Given that the package has been analysed, sort the classes
  /// deterministically (within a given input) and re-assign their ids based on
  /// this order.
  void canonicalizeClasses() {
    // reverse map of classDefinitions
    // for looking up the uri of the library where a class is defined
    var classDefinitionsInverse = <int, String>{};

    // construct inverse map defined above
    for (final library in classDefinitions.entries) {
      for (final thisClass in library.value) {
        classDefinitionsInverse[thisClass] = library.key;
      }
    }

    // sort classes first by name, then by the name of the defining library
    package.classes.sortBy(
        (thisClass) => thisClass.name + classDefinitionsInverse[thisClass.id]!);

    // maps old ids to new ids
    var newIdMapping = <int, int>{};
    var newIdCounter = 0;

    // create mapping and reassign ids in [package.classes]
    for (final thisClass in package.classes) {
      newIdMapping[thisClass.id] = newIdCounter;
      thisClass.id = newIdCounter;
      newIdCounter += 1;
    }

    // reassign ids in [package.libraries]
    for (final library in package.libraries) {
      library.exportedClasses = library.exportedClasses
          .map((classId) => newIdMapping[classId]!)
          .sorted(Comparable.compare)
          .toSet();
    }
  }

  var collection = packageAnalysisContext.analysisContextCollection;

  for (var context in collection.contexts) {
    for (var filePath in context.contextRoot.analyzedFiles().sorted()) {
      final session = context.currentSession;
      final library = await session.getResolvedLibrary(filePath);

      // match [packageLocation]/lib/*.dart
      // but exclude [packageLocation]/lib/src/*.dart
      if (!(path.isWithin(path.join(packageLocation, 'lib'), filePath) &&
          !path.isWithin(path.join(packageLocation, 'lib', 'src'), filePath) &&
          path.extension(filePath) == '.dart')) {
        continue;
      }

      // this file is just part of another library
      if (library is NotLibraryButPartResult) {
        continue;
      }

      // ensure that resolving has been successful
      if (library is! ResolvedLibraryResult) {
        packageAnalysisContext
            .warning('analysis of $filePath as a library failed');
        continue;
      }

      summarizeLibraryElement(
          library.element, path.relative(filePath, from: packageLocation));
    }
  }

  final allLibraryIdentifiers = classDefinitions.keys.toList();

  // add classes exported in the same library they are defined
  for (final libraryIdentifier in allLibraryIdentifiers) {
    classExports[libraryIdentifier] = <int>{};
    classExports[libraryIdentifier]!
        .addAll(classDefinitions[libraryIdentifier]!);
  }

  var hasFixedPoint = false;
  while (!hasFixedPoint) {
    // initially assume we have a fixed point
    hasFixedPoint = true;
    for (final libraryIdentifier in allLibraryIdentifiers) {
      for (final exportedLibrary in libraryExports[libraryIdentifier]!) {
        // everything in `exportedLibrary` is also exported in
        // `libraryIdentifier` if it isn't already
        if (!classExports[libraryIdentifier]!
            .containsAll(classExports[exportedLibrary]!)) {
          // at least some symbols aren't already exported
          classExports[libraryIdentifier]!
              .addAll(classExports[exportedLibrary]!);
          // we made some changes
          hasFixedPoint = false;
        }
      }
    }
  }

  // fill in [package] with information from classExports
  for (var library in package.libraries) {
    library.exportedClasses.addAll(classExports[library.uri]!);
  }

  canonicalizeClasses();

  return package;
}
