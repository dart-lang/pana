import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:pana/src/package_analysis/shape.dart';
import 'package:path/path.dart' as path;

import 'common.dart';

Future<PackageShape> summarizePackage(
  PackageAnalysisContext packageAnalysisContext,
  String packageLocation,
) async {
  var collection = packageAnalysisContext.analysisContextCollection;

  var libraryShapes = <LibraryShape>[];

  for (var context in collection.contexts) {
    for (var filePath in context.contextRoot.analyzedFiles()) {
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

      libraryShapes.add(summarizeLibraryElement(
          library.element, path.relative(filePath, from: packageLocation)));
    }
  }

  return PackageShape(libraryShapes);
}

LibraryShape summarizeLibraryElement(
    LibraryElement libraryElement, String libraryPath) {
  var classes = libraryElement.topLevelElements
      .where((element) => (element.isPublic && element is ClassElement))
      .map((element) => summarizeClassElement(element as ClassElement))
      .toList();
  return LibraryShape(libraryPath, classes);
}

ClassShape summarizeClassElement(ClassElement classElement) {
  var methods = classElement.methods
      .where((element) => element.isPublic)
      .map(summarizeMethodElement)
      .toList();
  return ClassShape(classElement.name, methods);
}

MethodShape summarizeMethodElement(MethodElement methodElement) {
  return MethodShape(methodElement.name);
}
