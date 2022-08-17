import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:collection/collection.dart';
import 'package:pana/src/package_analysis/package_analysis.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:pana/src/package_analysis/shapes_ext.dart';
import 'package:pana/src/package_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';

import 'common.dart';

/// Analyze the target package [targetName], using the temporary directory
/// [tempPath] to perform analysis, and return a [List] of any found issues -
/// where a symbol usage cannot be found in the relevant dependency's
/// [PackageShape].
///
/// If [cachePath] is provided, this folder is used to store cached package
/// metadata. If [pubHostedUrl] is provided, it is used instead of `'pub.dev'`
/// to retrieve package version information.
Future<List<LowerBoundConstraintIssue>> lowerBoundConstraintAnalysis({
  required String targetName,
  required String tempPath,
  String? cachePath,
  String? pubHostedUrl,
}) async {
  final dummyPath = path.join(tempPath, 'target');
  final dependencyFolder = path.join(tempPath, 'dependencies');

  try {
    await fetchUsingDummyPackage(
      name: targetName,
      version: (await fetchSortedPackageVersionList(
        packageName: targetName,
        cachePath: cachePath,
        pubHostedUrl: pubHostedUrl,
      ))
          .last,
      destination: dummyPath,
      wipeTarget: true,
      pubHostedUrl: pubHostedUrl,
    );
  } on ProcessException catch (exception) {
    throw AnalysisException(
        'Failed to download target package $targetName with error code ${exception.errorCode}: ${exception.message}');
  }

  // create session for analysing the package being searched for issues (the target package)
  final collection = AnalysisContextCollection(includedPaths: [dummyPath]);
  final context = PackageAnalysisContextWithStderr(
    session: collection.contextFor(dummyPath).currentSession,
    packagePath: dummyPath,
    targetPackageName: targetName,
  );

  // if there are no dependencies, there are no issues
  if (context.dependencies.isEmpty) {
    return [];
  }

  final dependencySummaries = <String, PackageShape>{};

  // iterate over each dependency of the target package and for each one:
  // - determine minimum allowed version
  // - determine installed (current/actual) version
  // - download minimum allowed version
  // - produce a summary of the minimum allowed version
  for (final dependencyEntry in context.dependencies.entries) {
    final dependencyName = dependencyEntry.key;
    final dependencyVersionConstraint = dependencyEntry.value.version;
    final dependencyDestination =
        path.join(dependencyFolder, '${dependencyName}_dummy');

    // determine the minimum allowed version of this dependency as allowed
    // by the constraints imposed by the target package
    final allVersions = await fetchSortedPackageVersionList(
      packageName: dependencyName,
      cachePath: cachePath,
      pubHostedUrl: pubHostedUrl,
    );
    final minVersion =
        allVersions.firstWhereOrNull(dependencyVersionConstraint.allows);

    if (minVersion == null) {
      context.warning(
          'Skipping dependency $dependencyName, could not determine minimum allowed version.');
      continue;
    }

    // download minimum allowed version of dependency
    try {
      await fetchUsingDummyPackage(
        name: dependencyName,
        version: minVersion,
        destination: dependencyDestination,
        wipeTarget: true,
        pubHostedUrl: pubHostedUrl,
      );
    } on ProcessException catch (exception) {
      // it is expected that sometimes the SDK constraint on the lowest version of the dependency will be too low
      if (!(exception.errorCode == 1 &&
          exception.message.contains('which requires SDK version') &&
          exception.message.endsWith('version solving failed.\n'))) {
        context.warning(
            'Skipping dependency $dependencyName of target package $targetName, failed to download it with error code ${exception.errorCode}: ${exception.message}');
      }
      continue;
    }

    // create session for producing a summary of this dependency
    final collection = AnalysisContextCollection(includedPaths: [
      dependencyDestination,
    ]);
    final dependencyPackageAnalysisContext = PackageAnalysisContextWithStderr(
      session: collection.contextFor(dependencyDestination).currentSession,
      packagePath: dependencyDestination,
    );

    // produce a summary of the minimum version of this dependency and store it
    dependencySummaries[dependencyName] = await summarizePackage(
      context: dependencyPackageAnalysisContext,
      packagePath:
          dependencyPackageAnalysisContext.findPackagePath(dependencyName),
    );
  }

  var astVisitor = _LowerBoundConstraintVisitor(
    context: context,
    dependencySummaries: dependencySummaries,
  );

  final libPath = path.join(context.packagePath, 'lib');
  final libFolder = context.folder(libPath);

  // retrieve the paths of all the dart library files in this package via the
  // resourceProvider (.dart files in ./lib)
  final dartLibFiles = getAllFiles(libFolder)
      .where((file) => path.extension(file.path) == '.dart')
      .map((file) => file.path)
      .sorted();

  for (final filePath in dartLibFiles) {
    final result = await context.analysisSession.getResolvedUnit(filePath);
    if (result is ResolvedUnitResult) {
      astVisitor.visitCompilationUnit(result.unit);
    } else {
      context.warning(
          'Attempting to get a resolved unit for file $filePath resulted in an invalid result.');
    }
  }

  final issues = <LowerBoundConstraintIssue>[];
  final installedDependencySummaries = <String, PackageShape>{};

  for (final possibleIssue in astVisitor.issues.values.whereNotNull()) {
    // CHECK 1: eliminate false positives by checking whether the 'bad' identifier is
    // present in the current/installed version of the dependency - if it isn't
    // then we have not been able to detect a difference between the lower bound
    // version and the current version and the issue is a false positive

    // produce a summary of the currently-installed version of the defining dependency
    if (!installedDependencySummaries
        .containsKey(possibleIssue.dependencyPackageName)) {
      installedDependencySummaries[possibleIssue.dependencyPackageName] =
          await summarizePackage(
        context: context,
        packagePath:
            context.findPackagePath(possibleIssue.dependencyPackageName),
      );
    }
    final installedDependency =
        installedDependencySummaries[possibleIssue.dependencyPackageName]!;

    // if this identifier exists in the current version of the defining dependency,
    // this is not a false positive
    if (!possibleIssue.identifierExistsInPackage(
        package: installedDependency)) {
      continue;
    }

    // TODO: does this check need to come earlier? maybe we can run it elsewhere? think some more about this...
    // CHECK 2: look at the typedefs that are in scope/imported at the reference
    // sites to see if checking for an alias of possibleIssue.className may
    // reveal a false positive

    // ensure we are dealing with a class member and that issue.className != null
    if (possibleIssue.kind == ElementKind.FUNCTION) {
      // we cannot perform check 2 here
      issues.add(possibleIssue);
      continue;
    }

    // the names of the aliases which could have been used for each individual reference of the identifier
    final possibleParentNames = <List<String>>[];

    for (final reference in possibleIssue.references) {
      final typedefsHere = await context.findTypedefs(reference.sourceUrl!);
      if (typedefsHere[possibleIssue.parentName!] != null) {
        possibleParentNames.add(typedefsHere[possibleIssue.parentName!]!);
      }
    }

    // the names of the aliases which could have been used at all references of the identifier
    final commonParentNames = possibleParentNames.fold<Set<String>>(
        possibleParentNames.isEmpty
            ? <String>{}
            : possibleParentNames.first.toSet(),
        (a, b) => a.intersection(b.toSet()));

    // if replacing the parent class name with any one of the found aliases
    // results in the identifier being found in the dependency summary,
    // then we have a false positive because a typedef alias was used
    if (commonParentNames
        .any((classNameAlias) => possibleIssue.identifierExistsInPackage(
              package:
                  dependencySummaries[possibleIssue.dependencyPackageName]!,
              classNameAlias: classNameAlias,
            ))) {
      continue;
    }

    // checks 1 and 2 did not reveal a false positive
    issues.add(possibleIssue);
  }

  return issues;
}

class _LowerBoundConstraintVisitor extends GeneralizingAstVisitor {
  /// The [PackageAnalysisContext] corresponding to the package being analyzed.
  final PackageAnalysisContext context;

  /// The [Element] definition being analyzed.
  late Element element;

  /// The id of [element].
  late int elementId;

  // The name of the package which defines [element].
  late String packageName;

  // The summary of the package which defines [element].
  late PackageShape dependencyShape;

  /// The parent of [element].
  late Element parentElement;

  /// The [SourceSpan] corresponding to the invocation currently being analyzed.
  late SourceSpan span;

  /// The name of the symbol being analyzed.
  late String symbolName;

  /// The package URI for the currently analyzed unit, typically on the form
  /// `package:package_name/library_name.dart`.
  late Uri currentUri;

  /// Maps from [Element.id] to either [LowerBoundConstraintIssue] if the lower
  /// bound constraint on [LowerBoundConstraintIssue.dependencyPackageName] is
  /// too low, making [Element] when the lowest allowed version
  /// [LowerBoundConstraintIssue.lowestVersion] is used, or null otherwise.
  final Map<int, LowerBoundConstraintIssue?> issues = {};

  /// The summaries of each of the dependencies of the target package.
  final Map<String, PackageShape> dependencySummaries;

  _LowerBoundConstraintVisitor({
    required this.context,
    required this.dependencySummaries,
  });

  /// Attempt to identify the name of the defining library of [element],
  /// populating [packageName] and [dependencyShape].
  void identifyDependencyName() {
    if (parentElement.library == null) {
      throw AnalysisException('Could not determine library of parentElement.');
    }
    final tryPackageName =
        packageFromLibraryUri(parentElement.library!.identifier);
    // if the defining package isn't a HostedDependency of the target, then
    // this symbol cannot be analyzed
    if (tryPackageName == null ||
        !context.dependencies.keys.contains(tryPackageName)) {
      throw AnalysisException(
          'The defining package is not a HostedDependency of the target package.');
    }
    packageName = tryPackageName;

    if (!dependencySummaries.keys.contains(packageName)) {
      throw AnalysisException(
          'No summary was found for the defining package $packageName.');
    }
    dependencyShape = dependencySummaries[packageName]!;
  }

  /// Populate the various properties of this visitor based on information from
  /// this symbol, throwing an [AnalysisException] if the symbol does not need
  /// to be/cannot be analyzed.
  void processIdentifier(SimpleIdentifier identifier) {
    span = SourceFile.fromString(
      context.readFile(context.uriToPath(currentUri)!),
      url: currentUri,
    ).span(identifier.offset, identifier.end);

    elementId = element.id;
    // if the element is a getter or a setter, pull out just the variable name
    symbolName = element is PropertyAccessorElement
        ? (element as PropertyAccessorElement).variable.name
        : element.name!;

    // if we have seen this symbol before, we need to do no further analysis
    if (issues.containsKey(elementId)) {
      // if we have seen this element before and there is an issue with it,
      // add this usage/invocation to its list of references
      issues[elementId]?.references.add(span);
      throw AnalysisException(
          'The definition of this Element has already been visited.');
    }

    const supportedKinds = [
      ElementKind.FUNCTION,
      ElementKind.METHOD,
      ElementKind.GETTER,
      ElementKind.SETTER,
    ];
    if (!supportedKinds.contains(element.kind)) {
      // prior checks should have filtered out any invocations other than these
      throw StateError('Unexpected ElementKind ${element.kind}.');
    }
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    // this must be able to handle cases of a library split into multiple files
    // with the part keyword
    currentUri = node.declaredElement!.source.uri;
    super.visitCompilationUnit(node);
  }

  // TODO: do we need visitPropertyAccess too?
  // Invocations of getters and setters are represented by either PrefixedIdentifier or PropertyAccess nodes.
  // PropertyAccess: The access of a property of an object. Note, however, that
  // accesses to properties of objects can also be represented as
  // PrefixedIdentifier nodes in cases where the target is also a simple identifier.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // an access of an object property
    super.visitPrefixedIdentifier(node);

    final parentNode = node.parent;
    if (node.staticElement != null) {
      element = node.staticElement!;
    } else if (parentNode is AssignmentExpression &&
        parentNode.writeElement != null) {
      // this special case is needed to retrieve the PropertyAccessorElement for a setter
      element = parentNode.writeElement!;
    } else {
      // we cannot statically resolve what was invoked
      return;
    }

    if (element is! PropertyAccessorElement) {
      // a PrefixedIdentifier does not necessarily represent a property access
      return;
    } else if (node.prefix.staticType is FunctionType) {
      // do not allow the parent to be a Function
      // (this breaks the assertion node.prefix.staticType?.element != null )
      return;
    }

    try {
      processIdentifier(node.identifier);
      if (element.enclosingElement3 is ExtensionElement) {
        parentElement = element.enclosingElement3!;
      } else {
        parentElement =
            node.prefix.staticType?.element2! ?? node.prefix.staticElement!;
      }
      identifyDependencyName();
    } on AnalysisException {
      // do not continue if this invocation is unfit for analysis
      return;
    }

    late bool constraintIssue;

    if (parentElement is ClassElement) {
      // ignore generics
      if ((parentElement as ClassElement).typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = !dependencyShape.containsPropertyWithName(
          parentElement.name!, symbolName);
    } else if (parentElement is ExtensionElement) {
      constraintIssue = !dependencyShape.containsExtensionPropertyWithName(
          parentElement.name!, symbolName);
    } else {
      // we may be looking at a top-level getter or setter
      // context.warning('Subclass ${parentElement.toString()} of parentElement (getter/setter) is not supported.');
      return;
    }

    issues[elementId] = constraintIssue
        ? LowerBoundConstraintIssue(
      dependencyPackageName: packageName,
            constraint: context.dependencies[packageName]!.version,
            currentVersion: context.findInstalledVersion(packageName),
            lowestVersion: Version.parse(dependencyShape.version),
            identifier: symbolName,
            parentName: parentElement.name!,
            kind: element.kind,
            parentKind: parentElement.kind,
            references: [span],
          )
        : null;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // an invocation of a top-level function or a class method
    super.visitMethodInvocation(node);

    if (node.methodName.staticElement == null) {
      // we cannot statically resolve what was invoked
      return;
    }
    element = node.methodName.staticElement!;
    // TODO: does `element.declaration` help here?

    try {
      processIdentifier(node.methodName);
      if (element is FunctionElement ||
          element.enclosingElement3 is ExtensionElement) {
        parentElement = element.enclosingElement3!;
      } else if (node.parent is CascadeExpression) {
        // TODO: handle cascade notation
        return;
      } else if (node.target == null) {
        return;
      } else {
        // TODO: determining parentElement through node.target seems unreliable...
        parentElement = node.target!.staticType?.element2! ??
            (node.target! as Identifier).staticElement!;
      }
      identifyDependencyName();
    } on AnalysisException {
      // do not continue if this invocation is unfit for analysis
      return;
    }

    late bool constraintIssue;

    // differentiate between class methods and top-level functions
    if (parentElement is ClassElement) {
      // ignore generics
      if ((parentElement as ClassElement).typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = !dependencyShape.containsMethodWithName(
          parentElement.name!, symbolName);
    } else if (parentElement is CompilationUnitElement) {
      constraintIssue = !dependencyShape.containsFunctionWithName(symbolName);
    } else if (parentElement is ExtensionElement) {
      constraintIssue = !dependencyShape.containsExtensionMethodWithName(
          parentElement.name!, symbolName);
    } else {
      // context.warning('Subclass ${parentElement.toString()} of parentElement (method/function) is not supported.');
      return;
    }

    issues[elementId] = constraintIssue
        ? LowerBoundConstraintIssue(
      dependencyPackageName: packageName,
            constraint: context.dependencies[packageName]!.version,
            currentVersion: context.findInstalledVersion(packageName),
            lowestVersion: Version.parse(dependencyShape.version),
            identifier: symbolName,
            parentName: element.kind == ElementKind.FUNCTION
                ? null
                : parentElement.name!,
            kind: element.kind,
            parentKind: element.kind == ElementKind.FUNCTION
                ? null
                : parentElement.kind,
            references: [span],
          )
        : null;
  }
}

/// Returns the package name from a library identifier/uri, or null if
/// [libraryUri] isn't of the form `package:*/*`.
///
/// Example:
/// `packageFromLibraryUri('package:my_package/my_library.dart')` returns
/// `'my_package'`.
String? packageFromLibraryUri(String libraryUri) {
  if (libraryUri.startsWith('package:') && libraryUri.contains('/')) {
    final endIndex = libraryUri.indexOf('/');
    return libraryUri.substring(8, endIndex);
  }
  return null;
}

// TODO: rename this class? it is still useful to have this structure even if we are not sure whether this is a real issue or a false positive - consider LowerBoundConstraintIssueResult or similar
class LowerBoundConstraintIssue {
  /// The name of the package that has an incorrect lower bound dependency constraint
  final String dependencyPackageName;

  /// The constraint on [dependencyPackageName] in the pubspec file
  final VersionConstraint constraint;

  /// The latest version of [dependencyPackageName]
  final Version currentVersion;

  /// The lowest version of [dependencyPackageName] allowed by [constraint].
  /// This is the version which does not contain [identifier].
  final Version lowestVersion;

  /// The name of the identifier that is referenced in source code, and which is
  /// available in the latest version of [dependencyPackageName], but not in
  /// version [lowestVersion], which is allowed by the lower-bound dependency
  /// constraint [constraint].
  final String identifier;

  /// The name of the enclosing class/extension of the missing [identifier], or
  /// null if [identifier] is not a member of a class/extension.
  final String? parentName;

  // TODO: Use enumeration somehow to assert that this member is one of several supported values
  /// The [ElementKind] of the [Element] corresponding to the missing
  /// [identifier], one of [ElementKind.FUNCTION], [ElementKind.METHOD],
  /// [ElementKind.GETTER], [ElementKind.SETTER].
  final ElementKind kind;

  // TODO: Use enumeration somehow to assert that this member is one of several supported values
  /// The [ElementKind] of the parent [Element] of the missing [identifier],
  /// [parentName], one of [ElementKind.CLASS], [ElementKind.EXTENSION], or null
  /// if [identifier] is not a member of a class/extension.
  final ElementKind? parentKind;

  /// List of locations in the analyzed source code where [identifier] was referenced.
  final List<SourceSpan> references;

  // TODO: any way to make this cleaner?
  /// Does [package] (some version of the defining dependency) contain [identifier]?
  /// If [classNameAlias] is specified, it will be used instead of [parentName].
  bool identifierExistsInPackage({
    required PackageShape package,
    String? classNameAlias,
  }) {
    switch (kind) {
      case ElementKind.FUNCTION:
        return package.containsFunctionWithName(identifier);

      case ElementKind.METHOD:
        if (parentKind == ElementKind.CLASS) {
          return package.containsMethodWithName(
            classNameAlias ?? parentName!,
            identifier,
          );
        } else if (parentKind == ElementKind.EXTENSION) {
          return package.containsExtensionMethodWithName(
            parentName!,
            identifier,
          );
        } else {
          throw StateError('Unexpected parent ElementKind $parentKind.');
        }

      case ElementKind.GETTER:
        if (parentKind == ElementKind.CLASS) {
          return package.containsGetterWithName(
            classNameAlias ?? parentName!,
            identifier,
          );
        } else if (parentKind == ElementKind.EXTENSION) {
          return package.containsExtensionGetterWithName(
            parentName!,
            identifier,
          );
        } else {
          throw StateError('Unexpected parent ElementKind $parentKind.');
        }

      case ElementKind.SETTER:
        if (parentKind == ElementKind.CLASS) {
          return package.containsSetterWithName(
            classNameAlias ?? parentName!,
            identifier,
          );
        } else if (parentKind == ElementKind.EXTENSION) {
          return package.containsExtensionSetterWithName(
            parentName!,
            identifier,
          );
        } else {
          throw StateError('Unexpected parent ElementKind $parentKind.');
        }

      default:
        throw StateError('Unexpected identifier ElementKind $kind.');
    }
  }

  @override
  String toString() {
    return 'LowerBoundConstraintIssue{dependencyPackageName: $dependencyPackageName, constraint: $constraint, currentVersion: $currentVersion, lowestVersion: $lowestVersion, identifier: $identifier, kind: $kind}';
  }

  LowerBoundConstraintIssue({
    required this.dependencyPackageName,
    required this.constraint,
    required this.currentVersion,
    required this.lowestVersion,
    required this.identifier,
    required this.parentName,
    required this.kind,
    required this.parentKind,
    required this.references,
  });
}
