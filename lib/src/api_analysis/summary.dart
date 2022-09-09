// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:pana/pana.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'normalize_shape.dart';
import 'shapes.dart';
import 'shapes_ext.dart';

List<Annotation> _summarizeAnnotations(Element element) => [
      if (element.hasDeprecated) Annotation.deprecated,
      if (element.hasSealed) Annotation.sealed,
      if (element.hasVisibleForOverriding) Annotation.visibleForOverriding,
      if (element.hasVisibleForTesting) Annotation.visibleForTesting,
    ];

MethodShape _summarizeMethod(MethodElement methodElement) => MethodShape(
      name: methodElement.name,
    );

PropertyShape _summarizeProperty(PropertyAccessorElement property) =>
    PropertyShape(
      name: property.variable.name,
    );

NamedConstructorShape _summarizeNamedConstructor(
        ConstructorElement constructor) =>
    NamedConstructorShape(
      name: constructor.name,
    );

FunctionShape _summarizeFunction(FunctionElement functionElement) =>
    FunctionShape(
      id: functionElement.id,
      name: functionElement.name,
    );

GlobalPropertyShape _summarizeGlobalProperty(
        PropertyAccessorElement property) =>
    GlobalPropertyShape(id: property.id, name: property.variable.name);

TypedefShape _summarizeTypedef(TypeAliasElement typedefElement) => TypedefShape(
      id: typedefElement.id,
      name: typedefElement.name,
      targetClassId: typedefElement.aliasedType.element2 is ClassElement
          ? typedefElement.aliasedType.element2!.id
          : null,
    );

ExtensionShape _summarizeExtension(ExtensionElement extensionElement) {
  // an accessor is a getter or a setter
  final publicAccessors = extensionElement.accessors
      .where((element) => !element.isStatic)
      .where((element) => element.isPublic);
  final publicStaticAccessors = extensionElement.accessors
      .where((element) => element.isStatic)
      .where((element) => element.isPublic);

  final publicMethods =
      extensionElement.methods.where((element) => element.isPublic);

  final methods = publicMethods
      .where((element) => !element.isStatic)
      .map(_summarizeMethod)
      .toList();

  final staticMethods = publicMethods
      .where((element) => element.isStatic)
      .map(_summarizeMethod)
      .toList();

  final getters = publicAccessors
      .where((element) => element.isGetter)
      .map(_summarizeProperty)
      .toList();

  final setters = publicAccessors
      .where((element) => element.isSetter)
      .map(_summarizeProperty)
      .toList();

  final staticGetters = publicStaticAccessors
      .where((element) => element.isGetter)
      .map(_summarizeProperty)
      .toList();

  final staticSetters = publicStaticAccessors
      .where((element) => element.isSetter)
      .map(_summarizeProperty)
      .toList();

  return ExtensionShape(
    id: extensionElement.id,
    name: extensionElement.name!,
    extendedClassId: extensionElement.extendedType.element2!.id,
    getters: getters,
    setters: setters,
    methods: methods,
    staticGetters: staticGetters,
    staticSetters: staticSetters,
    staticMethods: staticMethods,
    annotations: _summarizeAnnotations(extensionElement),
  );
}

ClassShape _summarizeClassElement(ClassElement classElement) {
  // an accessor is a getter or a setter
  final publicAccessors = classElement.accessors
      .where((element) => !element.isStatic)
      .where((element) => element.isPublic);
  final publicStaticAccessors = classElement.accessors
      .where((element) => element.isStatic)
      .where((element) => element.isPublic);

  final publicMethods =
      classElement.methods.where((element) => element.isPublic);

  final methods = publicMethods
      .where((element) => !element.isStatic)
      .map(_summarizeMethod)
      .toList();

  final staticMethods = publicMethods
      .where((element) => element.isStatic)
      .map(_summarizeMethod)
      .toList();

  final getters = publicAccessors
      .where((element) => element.isGetter)
      .map(_summarizeProperty)
      .toList();

  final setters = publicAccessors
      .where((element) => element.isSetter)
      .map(_summarizeProperty)
      .toList();

  final staticGetters = publicStaticAccessors
      .where((element) => element.isGetter)
      .map(_summarizeProperty)
      .toList();

  final staticSetters = publicStaticAccessors
      .where((element) => element.isSetter)
      .map(_summarizeProperty)
      .toList();

  final unnamedConstructor =
      classElement.constructors.any((constructor) => constructor.name == '');

  final namedConstructors = classElement.constructors
      .where((constructor) => constructor.name != '')
      .map(_summarizeNamedConstructor)
      .toList();

  return ClassShape(
    id: classElement.id,
    name: classElement.name,
    getters: getters,
    setters: setters,
    methods: methods,
    staticGetters: staticGetters,
    staticSetters: staticSetters,
    staticMethods: staticMethods,
    unnamedConstructor: unnamedConstructor,
    namedConstructors: namedConstructors,
    annotations: _summarizeAnnotations(classElement),
  );
}

ClassShape _summarizeClassAndSuperclasses(ClassElement classElement) {
  // produce summaries of the class itself and any superclasses
  final classShape = _summarizeClassElement(classElement);
  final superTypeShapes = classElement.allSupertypes
      .map((interfaceType) => interfaceType.element2 as ClassElement)
      .map(_summarizeClassElement)
      .toList();

  // add the fields together
  classShape.extendWith(others: superTypeShapes);

  return classShape;
}

Future<PackageShape> summarizePackage({
  required PackageAnalysisContext context,
  required String packagePath,
  required bool normalize,
}) async {
  final pubspecString = context.readFile(path.join(
    packagePath,
    'pubspec.yaml',
  ));
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
    extensions: <ExtensionShape>[],
    typedefs: <TypedefShape>[],
  );

  void summarizeLibraryElement(LibraryElement libraryElement) {
    final uri = libraryElement.identifier;
    final exportedClasses = <int>{};
    final exportedGetters = <int>{};
    final exportedSetters = <int>{};
    final exportedFunctions = <int>{};
    final exportedTypedefs = <int>{};
    final exportedExtensions = <int>{};

    // public top-level elements which are exported by this library
    final publicSymbols = libraryElement.exportNamespace.definedNames.values;

    for (final classElement in publicSymbols.whereType<ClassElement>()) {
      exportedClasses.add(classElement.id);
      if (!package.classes.any((c) => classElement.id == c.id)) {
        package.classes.add(_summarizeClassAndSuperclasses(classElement));
      }
    }

    for (final accessorElement in publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isGetter)) {
      exportedGetters.add(accessorElement.id);
      if (!package.getters.any((g) => accessorElement.id == g.id)) {
        package.getters.add(_summarizeGlobalProperty(accessorElement));
      }
    }

    for (final accessorElement in publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isSetter)) {
      exportedSetters.add(accessorElement.id);
      if (!package.setters.any((s) => accessorElement.id == s.id)) {
        package.setters.add(_summarizeGlobalProperty(accessorElement));
      }
    }

    for (final functionElement in publicSymbols.whereType<FunctionElement>()) {
      exportedFunctions.add(functionElement.id);
      if (!package.functions.any((f) => functionElement.id == f.id)) {
        package.functions.add(_summarizeFunction(functionElement));
      }
    }

    for (final typedefElement in publicSymbols.whereType<TypeAliasElement>()) {
      exportedTypedefs.add(typedefElement.id);
      if (!package.typedefs.any((t) => typedefElement.id == t.id)) {
        final typedef = _summarizeTypedef(typedefElement);
        // If the aliased class is not already included in the summary,
        // then summarize it.
        if (typedef.targetClassId != null &&
            !package.classes.any((c) => c.id == typedef.targetClassId)) {
          package.classes.add(_summarizeClassAndSuperclasses(
              typedefElement.aliasedType.element2! as ClassElement));
        }
        package.typedefs.add(typedef);
      }
    }

    // Ensure it is a class that is being extended.
    for (final extensionElement in publicSymbols
        .whereType<ExtensionElement>()
        .where((e) => e.extendedType.element2 is ClassElement)) {
      exportedExtensions.add(extensionElement.id);
      if (!package.extensions.any((e) => extensionElement.id == e.id)) {
        final extension = _summarizeExtension(extensionElement);
        // If the extended class is not already included in the summary,
        // then summarize it.
        if (!package.classes.any((c) => c.id == extension.extendedClassId)) {
          package.classes.add(_summarizeClassAndSuperclasses(
              extensionElement.extendedType.element2! as ClassElement));
        }
        package.extensions.add(extension);
      }
    }

    package.libraries.add(LibraryShape(
      uri: uri,
      exportedClasses: exportedClasses.toList(),
      exportedGetters: exportedGetters.toList(),
      exportedSetters: exportedSetters.toList(),
      exportedFunctions: exportedFunctions.toList(),
      exportedTypedefs: exportedTypedefs.toList(),
      exportedExtensions: exportedExtensions.toList(),
    ));
  }

  final libPath = path.join(packagePath, 'lib');
  final libSrcPath = path.join(libPath, 'src');
  final libFolder = context.folder(libPath);

  // retrieve the paths of all the public dart files in this package via the
  // resourceProvider (.dart files in ./lib but not in ./lib/src)
  final nonSrcDartFiles = getAllFiles(libFolder)
      .where((file) => !path.isWithin(libSrcPath, file.path))
      .where((file) => path.extension(file.path) == '.dart')
      .map((file) => file.path)
      .sorted();

  for (final filePath in nonSrcDartFiles) {
    final library = await context.analysisSession.getResolvedLibrary(filePath);

    // this file is just part of another library
    if (library is NotLibraryButPartResult) {
      continue;
    }

    // ensure that resolving has been successful
    if (library is! ResolvedLibraryResult) {
      context.warning('Analysis of $filePath as a library failed.');
      continue;
    }

    summarizeLibraryElement(library.element);
  }

  return normalize ? normalizePackageShape(package) : package;
}
