import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'normalize_shape.dart';
import 'shapes.dart';

Future<PackageShape> summarizePackage(
  PackageAnalysisContext packageAnalysisContext,
  String packageLocation,
) async {
  final package = PackageShape(
    libraries: <LibraryShape>[],
    classes: <ClassShape>[],
  );

  ExecutableShape summarizeExecutableElement(ExecutableElement executableElement) {
    // ExecutableElement is a superclass of both MethodShape and FunctionShape
    return ExecutableShape(name: executableElement.name);
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
      setters: setters,
    );
  }

  void summarizeLibraryElement(
      LibraryElement libraryElement, String libraryPath) {
    final identifier = libraryElement.identifier;

    // public top-level elements which are exported by this library
    final publicSymbols = libraryElement.exportNamespace.definedNames;

    final classes = publicSymbols.values
        .whereType<ClassElement>()
        .map(summarizeClassElement)
        .toList();
    final classIds = classes.map((thisClass) => thisClass.id).toList();

    final getters = publicSymbols.values
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isGetter)
        .map(summarizeProperty)
        .toList();

    final setters = publicSymbols.values
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isSetter)
        .map(summarizeProperty)
        .toList();

    final functions = publicSymbols.values
        .whereType<FunctionElement>()
        .map(summarizeExecutableElement)
        .toList();

    package.classes.addAll(classes.where((thisClass) => !package.classes.contains(thisClass)));
    package.libraries.add(LibraryShape(
      uri: identifier,
      exportedClasses: classIds,
      getters: getters,
      setters: setters,
      functions: functions,
    ));
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

  return normalizePackageShape(package);
}
