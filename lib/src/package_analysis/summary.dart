import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:pana/pana.dart';
import 'package:pana/src/package_analysis/shapes_ext.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'normalize_shape.dart';
import 'shapes.dart';

Future<PackageShape> summarizePackage({
  required PackageAnalysisContext context,
  required String packagePath,
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

  List<Annotation> summarizeAnnotations(Element element) => [
        if (element.hasDeprecated) Annotation.deprecated,
        if (element.hasSealed) Annotation.sealed,
        if (element.hasVisibleForOverriding) Annotation.visibleForOverriding,
        if (element.hasVisibleForTesting) Annotation.visibleForTesting,
      ];

  MethodShape summarizeMethod(MethodElement methodElement) {
    return MethodShape(
      name: methodElement.name,
    );
  }

  PropertyShape summarizeProperty(PropertyAccessorElement property) {
    return PropertyShape(name: property.variable.name);
  }

  NamedConstructorShape summarizeNamedConstructor(
      ConstructorElement constructor) {
    return NamedConstructorShape(name: constructor.name);
  }

  FunctionShape summarizeFunction(FunctionElement functionElement) {
    return FunctionShape(
      id: functionElement.id,
      name: functionElement.name,
    );
  }

  GlobalPropertyShape summarizeGlobalProperty(
      PropertyAccessorElement property) {
    return GlobalPropertyShape(id: property.id, name: property.variable.name);
  }

  TypedefShape summarizeTypedef(TypeAliasElement typedefElement) {
    return TypedefShape(
      id: typedefElement.id,
      name: typedefElement.name,
      targetClassId: typedefElement.aliasedType.element2 is ClassElement
          ? typedefElement.aliasedType.element2!.id
          : null,
    );
  }

  ExtensionShape summarizeExtension(ExtensionElement extensionElement) {
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
        .map(summarizeMethod)
        .toList();

    final staticMethods = publicMethods
        .where((element) => element.isStatic)
        .map(summarizeMethod)
        .toList();

    final getters = publicAccessors
        .where((element) => element.isGetter)
        .map(summarizeProperty)
        .toList();

    final setters = publicAccessors
        .where((element) => element.isSetter)
        .map(summarizeProperty)
        .toList();

    final staticGetters = publicStaticAccessors
        .where((element) => element.isGetter)
        .map(summarizeProperty)
        .toList();

    final staticSetters = publicStaticAccessors
        .where((element) => element.isSetter)
        .map(summarizeProperty)
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
      annotations: summarizeAnnotations(extensionElement),
    );
  }

  ClassShape summarizeClassElement(ClassElement classElement) {
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
        .map(summarizeMethod)
        .toList();

    final staticMethods = publicMethods
        .where((element) => element.isStatic)
        .map(summarizeMethod)
        .toList();

    final getters = publicAccessors
        .where((element) => element.isGetter)
        .map(summarizeProperty)
        .toList();

    final setters = publicAccessors
        .where((element) => element.isSetter)
        .map(summarizeProperty)
        .toList();

    final staticGetters = publicStaticAccessors
        .where((element) => element.isGetter)
        .map(summarizeProperty)
        .toList();

    final staticSetters = publicStaticAccessors
        .where((element) => element.isSetter)
        .map(summarizeProperty)
        .toList();

    final unnamedConstructor =
        classElement.constructors.any((constructor) => constructor.name == '');

    final namedConstructors = classElement.constructors
        .where((constructor) => constructor.name != '')
        .map(summarizeNamedConstructor)
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
      annotations: summarizeAnnotations(classElement),
    );
  }

  ClassShape summarizeClassAndSuperclasses(ClassElement classElement) {
    // produce summaries of the class itself and any superclasses
    final classShape = summarizeClassElement(classElement);
    final superTypeShapes = classElement.allSupertypes
        .map((interfaceType) => interfaceType.element2 as ClassElement)
        .map(summarizeClassElement)
        .toList();

    // add the fields together
    classShape.add(others: superTypeShapes);

    return classShape;
  }

  void summarizeLibraryElement(LibraryElement libraryElement) {
    final uri = libraryElement.identifier;
    final exportedClasses = <int>[];
    final exportedGetters = <int>[];
    final exportedSetters = <int>[];
    final exportedFunctions = <int>[];
    final exportedTypedefs = <int>[];
    final exportedExtensions = <int>[];

    // public top-level elements which are exported by this library
    final publicSymbols = libraryElement.exportNamespace.definedNames.values;

    final classes =
        publicSymbols.whereType<ClassElement>().where((classElement) {
      exportedClasses.add(classElement.id);
      return !package.classes
          .any((thisClass) => classElement.id == thisClass.id);
    }).map(summarizeClassAndSuperclasses);
    package.classes.addAll(classes);

    final getters = publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isGetter)
        .where((accessorElement) {
      exportedGetters.add(accessorElement.id);
      return !package.getters.any((getter) => accessorElement.id == getter.id);
    }).map(summarizeGlobalProperty);
    package.getters.addAll(getters);

    final setters = publicSymbols
        .whereType<PropertyAccessorElement>()
        .where((element) => element.isSetter)
        .where((accessorElement) {
      exportedSetters.add(accessorElement.id);
      return !package.setters.any((setter) => accessorElement.id == setter.id);
    }).map(summarizeGlobalProperty);
    package.setters.addAll(setters);

    final functions =
        publicSymbols.whereType<FunctionElement>().where((functionElement) {
      exportedFunctions.add(functionElement.id);
      return !package.functions
          .any((function) => functionElement.id == function.id);
    }).map(summarizeFunction);
    package.functions.addAll(functions);

    final typedefs =
        publicSymbols.whereType<TypeAliasElement>().where((typedefElement) {
      exportedTypedefs.add(typedefElement.id);
      return !package.typedefs
          .any((thisTypedef) => typedefElement.id == thisTypedef.id);
    }).map((typedefElement) {
      final typedef = summarizeTypedef(typedefElement);
      // if the aliased class is not already included in the summary,
      // then summarize it
      if (typedef.targetClassId != null &&
          !package.classes
              .any((thisClass) => thisClass.id == typedef.targetClassId)) {
        package.classes.add(summarizeClassAndSuperclasses(
            typedefElement.aliasedType.element2! as ClassElement));
      }
      return typedef;
    });
    package.typedefs.addAll(typedefs);

    final extensions = publicSymbols
        .whereType<ExtensionElement>()
        .where((extensionElement) =>
            // ensure it is a class that is being extended
            extensionElement.extendedType.element2 is ClassElement)
        .where((extensionElement) {
      exportedExtensions.add(extensionElement.id);
      return !package.extensions
          .any((thisExtension) => extensionElement.id == thisExtension.id);
    }).map((extensionElement) {
      final extension = summarizeExtension(extensionElement);
      // if the extended class is not already included in the summary,
      // then summarize it
      if (!package.classes
          .any((thisClass) => thisClass.id == extension.extendedClassId)) {
        package.classes.add(summarizeClassAndSuperclasses(
            extensionElement.extendedType.element2! as ClassElement));
      }
      return extension;
    });
    package.extensions.addAll(extensions);

    package.libraries.add(LibraryShape(
      uri: uri,
      exportedClasses: exportedClasses,
      exportedGetters: exportedGetters,
      exportedSetters: exportedSetters,
      exportedFunctions: exportedFunctions,
      exportedTypedefs: exportedTypedefs,
      exportedExtensions: exportedExtensions,
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

  return normalizePackageShape(package);
}
