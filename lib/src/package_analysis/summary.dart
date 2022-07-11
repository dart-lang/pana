import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:pana/pana.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'normalize_shape.dart';
import 'shapes.dart';

Future<PackageShape> summarizePackage(
  PackageAnalysisContext packageAnalysisSession,
  String packageLocation,
) async {
  final pubspecPath = path.join(packageLocation, 'pubspec.yaml');
  final pubspecString = packageAnalysisSession.analysisSession.resourceProvider
      .getFile(pubspecPath)
      .readAsStringSync();
  final pubspec = Pubspec.parseYaml(pubspecString);

  if (pubspec.version == null) {
    throw StateError(
        'Specify a version number in `pubspec.yaml` before running analysis.');
  }

  final package = PackageShape(
    name: pubspec.name,
    version: pubspec.version!.toString(),
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

    final classes =
        publicSymbols.whereType<ClassElement>()
        .where((classElement) {
      exportedClasses.add(classElement.id);
      return !package.classes
          .any((thisClass) => classElement.id == thisClass.id);
    }).map(summarizeClassElement);

    final getters = publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isGetter)
        .where((accessorElement) {
      exportedGetters.add(accessorElement.id);
      return !package.getters.any((getter) => accessorElement.id == getter.id);
    }).map(summarizeGlobalProperty);

    final setters = publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isSetter)
        .where((accessorElement) {
      exportedSetters.add(accessorElement.id);
      return !package.setters.any((setter) => accessorElement.id == setter.id);
    }).map(summarizeGlobalProperty);

    final functions = publicSymbols
        .whereType<FunctionElement>()
        .where((functionElement) {
      exportedFunctions.add(functionElement.id);
      return !package.functions
          .any((function) => functionElement.id == function.id);
    }).map(summarizeFunction);

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

  final libPath = path.join(packageLocation, 'lib');
  final libSrcPath = path.join(libPath, 'src');
  final libFolder = packageAnalysisSession.analysisSession.resourceProvider
      .getFolder(libPath);

  // retrieve the paths of all the public dart files in this package via the
  // resourceProvider (.dart files in ./lib but not in ./lib/src)
  final nonSrcDartFiles = getAllFiles(libFolder)
      .where((file) => !path.isWithin(libSrcPath, file.path))
      .where((file) => path.extension(file.path) == '.dart')
      .map((file) => file.path)
      .sorted();

  for (final filePath in nonSrcDartFiles) {
    final library = await packageAnalysisSession.analysisSession
        .getResolvedLibrary(filePath);

    // this file is just part of another library
    if (library is NotLibraryButPartResult) {
      continue;
    }

    // ensure that resolving has been successful
    if (library is! ResolvedLibraryResult) {
      packageAnalysisSession
          .warning('Analysis of $filePath as a library failed.');
      continue;
    }

    summarizeLibraryElement(
      library.element,
      path.relative(filePath, from: packageLocation),
    );
  }

  return normalizePackageShape(package);
}
