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
  var classCounter = 0;
  final package =
      PackageShape(libraries: <LibraryShape>[], classes: <ClassShape>[]);

  /// Ids of classes defined in a given library
  final classDefinitions = <String, Set<int>>{};

  /// Identifiers of libraries exported in a given library
  final libraryExports = <String, List<String>>{};

  /// Ids of classes exported in a given library
  final classExports = <String, Set<int>>{};

  MethodShape summarizeMethodElement(MethodElement methodElement) {
    return MethodShape(name: methodElement.name);
  }

  ClassShape summarizeClassElement(ClassElement classElement) {
    var methods = classElement.methods
        .where((element) => element.isPublic)
        .map(summarizeMethodElement)
        .toList();
    classCounter += 1;
    return ClassShape(
        id: classCounter, name: classElement.name, methods: methods);
  }

  void summarizeLibraryElement(
      LibraryElement libraryElement, String libraryPath) {
    var identifier = libraryElement.identifier;

    // classes defined in this library
    var classes = libraryElement.topLevelElements
        .where((element) => (element.isPublic && element is ClassElement))
        .map((element) => summarizeClassElement(element as ClassElement))
        .toList();
    var classIds = classes.map((thisClass) => thisClass.id).toSet();

    package.classes.addAll(classes);
    package.libraries
        .add(LibraryShape(uri: identifier, exportedClasses: <int>{}));

    classDefinitions[identifier] = classIds;
    libraryExports[identifier] = libraryElement.exportedLibraries
        .map((library) => library.identifier)
        .toList();
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

  return package;
}
