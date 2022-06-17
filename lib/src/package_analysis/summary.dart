import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:pana/src/package_analysis/shape.dart';
import 'package:path/path.dart' as path;

import 'common.dart';

class Summarizer {
  var _classCounter = 0;
  final _package = PackageShape(<LibraryShape>[], <ClassShape>[]);

  /// Ids of classes defined in a given library
  final _classDefinitions = <String, Set<int>>{};

  /// Identifiers of libraries exported in a given library
  final _libraryExports = <String, List<String>>{};

  /// Ids of classes exported in a given library
  final _classExports = <String, Set<int>>{};

  Future<PackageShape> summarizePackage(
    PackageAnalysisContext packageAnalysisContext,
    String packageLocation,
  ) async {
    var collection = packageAnalysisContext.analysisContextCollection;

    for (var context in collection.contexts) {
      for (var filePath in context.contextRoot.analyzedFiles().sorted()) {
        final session = context.currentSession;
        final library = await session.getResolvedLibrary(filePath);

        // match [packageLocation]/lib/*.dart
        // but exclude [packageLocation]/lib/src/*.dart
        if (!(path.isWithin(path.join(packageLocation, 'lib'), filePath) &&
            !path.isWithin(
                path.join(packageLocation, 'lib', 'src'), filePath) &&
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

    final allLibraryIdentifiers = _classDefinitions.keys.toList();

    // add classes exported in the same library they are defined
    for (final libraryIdentifier in allLibraryIdentifiers) {
      _classExports[libraryIdentifier] = <int>{};
      _classExports[libraryIdentifier]!
          .addAll(_classDefinitions[libraryIdentifier]!);
    }

    var hasFixedPoint = false;
    while (!hasFixedPoint) {
      // initially assume we have a fixed point
      hasFixedPoint = true;
      for (final libraryIdentifier in allLibraryIdentifiers) {
        for (final exportedLibrary in _libraryExports[libraryIdentifier]!) {
          // everything in `exportedLibrary` is also exported in
          // `libraryIdentifier` if it isn't already
          if (!_classExports[libraryIdentifier]!
              .containsAll(_classExports[exportedLibrary]!)) {
            // at least some symbols aren't already exported
            _classExports[libraryIdentifier]!
                .addAll(_classExports[exportedLibrary]!);
            // we made some changes
            hasFixedPoint = false;
          }
        }
      }
    }

    // fill in `_package` with information from _classExports
    for (var library in _package.libraries) {
      library.exportedClasses.addAll(_classExports[library.identifier]!);
    }

    return _package;
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

    _package.classes.addAll(classes);
    _package.libraries.add(LibraryShape(identifier, <int>{}));

    _classDefinitions[identifier] = classIds;
    _libraryExports[identifier] = libraryElement.exportedLibraries
        .map((library) => library.identifier)
        .toList();
  }

  ClassShape summarizeClassElement(ClassElement classElement) {
    var methods = classElement.methods
        .where((element) => element.isPublic)
        .map(summarizeMethodElement)
        .toList();
    _classCounter += 1;
    return ClassShape(_classCounter, classElement.name, methods);
  }

  MethodShape summarizeMethodElement(MethodElement methodElement) {
    return MethodShape(methodElement.name);
  }
}
