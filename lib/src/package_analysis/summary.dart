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

  MethodShape summarizeMethod(
      ExecutableElement executableElement) {
    return MethodShape(
      name: executableElement.name,
    );
  }

  FunctionShape summarizeFunction(
      ExecutableElement executableElement) {
    return FunctionShape(
      id: executableElement.id,
      name: executableElement.name,
    );
  }

  PropertyShape summarizeProperty(PropertyAccessorElement property) {
    return PropertyShape(name: property.variable.name);
  }

  GlobalPropertyShape summarizeGlobalProperty(PropertyAccessorElement property) {
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
    final identifier = libraryElement.identifier;

    // public top-level elements which are exported by this library
    final publicSymbols = libraryElement.exportNamespace.definedNames.values;

    final classes = publicSymbols
        .whereType<ClassElement>()
        .map(summarizeClassElement);

    final getters = publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isGetter)
        .map(summarizeGlobalProperty);

    final setters = publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isSetter)
        .map(summarizeGlobalProperty);

    final functions = publicSymbols
        .whereType<FunctionElement>()
        .map(summarizeFunction);

    package.getters
        .addAll(getters.where((getter) => !package.getters.contains(getter)));
    package.setters
        .addAll(setters.where((setter) => !package.setters.contains(setter)));
    package.functions.addAll(
        functions.where((function) => !package.functions.contains(function)));
    package.classes.addAll(
        classes.where((thisClass) => !package.classes.contains(thisClass)));
    package.libraries.add(LibraryShape(
      uri: identifier,
      exportedClasses: classes.map((thisClass) => thisClass.id).toList(),
      exportedGetters: getters.map((getter) => getter.id).toList(),
      exportedSetters: setters.map((setter) => setter.id).toList(),
      exportedFunctions: functions.map((function) => function.id).toList(),
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
