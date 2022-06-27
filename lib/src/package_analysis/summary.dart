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
    getters: <GlobalPropertyShape>[],
    setters: <GlobalPropertyShape>[],
    functions: <FunctionShape>[],
    classes: <ClassShape>[],
  );

  MethodShape summarizeMethod(MethodElement methodElement) {
    return MethodShape(
      name: methodElement.name,
    );
  }

  FunctionShape summarizeFunction(FunctionElement functionElement) {
    return FunctionShape(
      id: functionElement.id,
      name: functionElement.name,
    );
  }

  PropertyShape summarizeProperty(PropertyAccessorElement property) {
    return PropertyShape(name: property.variable.name);
  }

  GlobalPropertyShape summarizeGlobalProperty(
      PropertyAccessorElement property) {
    return GlobalPropertyShape(id: property.id, name: property.variable.name);
  }

  ClassShape summarizeClassElement(ClassElement classElement) {
    final methods = classElement.methods
        .where((element) => element.isPublic)
        .map(summarizeMethod)
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
    final uri = libraryElement.identifier;
    final exportedClasses = <int>[];
    final exportedGetters = <int>[];
    final exportedSetters = <int>[];
    final exportedFunctions = <int>[];

    // public top-level elements which are exported by this library
    final publicSymbols = libraryElement.exportNamespace.definedNames.values;

    final classes = publicSymbols
        .whereType<ClassElement>()
        .where((classElement) {
          exportedClasses.add(classElement.id);
          return !package.classes
              .any((thisClass) => classElement.id == thisClass.id);
        })
        .map(summarizeClassElement);

    final getters = publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isGetter)
        .where((accessorElement) {
          exportedGetters.add(accessorElement.id);
          return !package.getters
              .any((getter) => accessorElement.id == getter.id);
        })
        .map(summarizeGlobalProperty);

    final setters = publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isSetter)
        .where((accessorElement) {
          exportedSetters.add(accessorElement.id);
          return !package.setters
              .any((setter) => accessorElement.id == setter.id);
        })
        .map(summarizeGlobalProperty);

    final functions = publicSymbols
        .whereType<FunctionElement>()
        .where((functionElement) {
          exportedFunctions.add(functionElement.id);
          return !package.functions
              .any((function) => functionElement.id == function.id);
        })
        .map(summarizeFunction);

    package.getters.addAll(getters);
    package.setters.addAll(setters);
    package.functions.addAll(functions);
    package.classes.addAll(classes);
    package.libraries.add(LibraryShape(
      uri: uri,
      exportedClasses: exportedClasses,
      exportedGetters: exportedGetters,
      exportedSetters: exportedSetters,
      exportedFunctions: exportedFunctions,
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
