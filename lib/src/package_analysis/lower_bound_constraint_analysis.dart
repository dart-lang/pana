import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:collection/collection.dart';
import 'package:pana/src/package_analysis/kind.dart';
import 'package:pana/src/package_analysis/package_analysis.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:pana/src/package_analysis/shapes_ext.dart';
import 'package:pana/src/package_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';

import 'common.dart';
import 'issue.dart';

/// Analyze the target package [targetName], using the temporary directory
/// [tempPath] to perform analysis, and return a [List] of any found issues -
/// where a symbol usage cannot be found in the relevant dependency's
/// [PackageShape].
///
/// If [cachePath] is provided, this folder is used to store cached package
/// metadata.
///
/// If [pubHostedUrl] is provided, it is used instead of `'pub.dev'` to retrieve
/// package version information.
///
/// If [pubCachePath] is provided, its value is used as the pub cache path while
/// fetching packages.
Future<List<PotentialLowerBoundConstraintIssue>> lowerBoundConstraintAnalysis({
  required String targetName,
  required String tempPath,
  String? cachePath,
  String? pubHostedUrl,
  String? pubCachePath,
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
          .last
          .toString(),
      destination: dummyPath,
      pubHostedUrl: pubHostedUrl,
      pubCachePath: pubCachePath,
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
        version: minVersion.toString(),
        destination: dependencyDestination,
        pubHostedUrl: pubHostedUrl,
        pubCachePath: pubCachePath,
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

  final astVisitor = _LowerBoundConstraintVisitor(
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

  final issues = <PotentialLowerBoundConstraintIssue>[];
  final installedDependencySummaries = <String, PackageShape>{};

  for (final possibleIssue in astVisitor.issues.values.whereNotNull()) {
    // CURRENT DEPENDENCY VERSION CHECK: eliminate false positives by checking
    // whether the 'missing' identifier is present in the current/installed
    // version of the dependency - if it isn't then we have not been able to
    // detect a difference between the lower bound version and the current
    // version, and the issue is a false positive

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

    // if this identifier does not exist in the current version of the defining
    // dependency, this is a false positive
    if (!possibleIssue.identifierExistsInPackage(
        package: installedDependency)) {
      continue;
    }

    // TYPEDEF CHECK: look at the typedefs that are in scope/imported at the
    // reference sites to see if checking for an alias of
    // possibleIssue.className may reveal a false positive

    // ensure we are dealing with a class member and that issue.className != null
    if (possibleIssue.kind == Kind.function) {
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

    // neither the current dependency version check nor the typedef check could reveal a false positive
    issues.add(possibleIssue);
  }

  return issues;
}

class _LowerBoundConstraintVisitor extends GeneralizingAstVisitor {
  /// The [PackageAnalysisContext] corresponding to the package being analyzed.
  final PackageAnalysisContext context;

  /// The package URI for the currently analyzed unit, typically on the form
  /// `package:package_name/library_name.dart`.
  late Uri currentUri;

  /// Maps from [Element.id] to either [PotentialLowerBoundConstraintIssue] if the lower
  /// bound constraint on [PotentialLowerBoundConstraintIssue.dependencyPackageName] is
  /// too low, making [Element] when the lowest allowed version
  /// [PotentialLowerBoundConstraintIssue.lowestVersion] is used, or null otherwise.
  final Map<int, PotentialLowerBoundConstraintIssue?> issues = {};

  /// The summaries of each of the dependencies of the target package.
  final Map<String, PackageShape> dependencySummaries;

  _LowerBoundConstraintVisitor({
    required this.context,
    required this.dependencySummaries,
  });

  /// Attempt to identify the name of the defining library of [element].
  IdentifierDependencyMetadata identifyDependencyName({
    required Element element,
  }) {
    if (element.library == null) {
      throw AnalysisException('Could not determine library of parentElement.');
    }
    final tryPackageName = packageFromLibraryUri(element.library!.identifier);
    // if the defining package isn't a HostedDependency of the target, then
    // this symbol cannot be analyzed
    if (tryPackageName == null ||
        !context.dependencies.keys.contains(tryPackageName)) {
      throw AnalysisException(
          'The defining package is not a HostedDependency of the target package.');
    }

    if (!dependencySummaries.keys.contains(tryPackageName)) {
      throw AnalysisException(
          'No summary was found for the defining package $tryPackageName.');
    }
    return IdentifierDependencyMetadata(
      packageName: tryPackageName,
      packageShape: dependencySummaries[tryPackageName]!,
    );
  }

  /// Collect metadata of this symbol, throwing an [AnalysisException] if the
  /// symbol does not need to be/cannot be analyzed.
  IdentifierMetadata processIdentifier(
    SimpleIdentifier identifier, {
    required Element element,
  }) {
    final identifierMetadata = IdentifierMetadata(
      span: SourceFile.fromString(
        context.readFile(context.uriToPath(currentUri)!),
        url: currentUri,
      ).span(identifier.offset, identifier.end),
      elementId: element.id,
      // if the element is a getter or a setter, pull out just the variable name
      identifierName: element is PropertyAccessorElement
          ? element.variable.name
          : element.name!,
    );

    // if we have seen this symbol before, we need to do no further analysis
    if (issues.containsKey(identifierMetadata.elementId)) {
      // if we have seen this element before and there is an issue with it,
      // add this usage/invocation to its list of references
      issues[identifierMetadata.elementId]
          ?.references
          .add(identifierMetadata.span);
      throw AnalysisException(
          'The definition of this Element has already been visited.');
    }

    return identifierMetadata;
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    // this must be able to handle cases of a library split into multiple files
    // with the part keyword
    currentUri = node.declaredElement!.source.uri;
    super.visitCompilationUnit(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // an access of an object property
    super.visitPrefixedIdentifier(node);

    // the definition of the symbol being analysed, and its parent (where applicable)
    late final Element element;
    late final Element parentElement;

    final parentNode = node.parent;
    if (node.staticElement != null) {
      element = node.staticElement!;
    } else if (parentNode is AssignmentExpression &&
        parentNode.writeElement != null) {
      // this special case is needed to retrieve the PropertyAccessorElement for a setter
      element = parentNode.writeElement!;
    } else if (node.identifier.staticElement != null) {
      element = node.identifier.staticElement!;
    } else {
      // we cannot statically resolve what was invoked
      return;
    }

    if (element is! PropertyAccessorElement && element is! MethodElement) {
      // a PrefixedIdentifier does not necessarily represent a property access
      return;
    } else if (node.prefix.staticType is FunctionType) {
      // do not allow the parent to be a Function
      // (this breaks the assertion node.prefix.staticType?.element != null )
      return;
    }

    late final IdentifierMetadata metadata;
    late final IdentifierDependencyMetadata dependencyMetadata;
    try {
      metadata = processIdentifier(node.identifier, element: element);
      if (element.enclosingElement3 is ExtensionElement) {
        parentElement = element.enclosingElement3!;
      } else {
        parentElement =
            node.prefix.staticType?.element2! ?? node.prefix.staticElement!;
      }
      dependencyMetadata = identifyDependencyName(element: parentElement);
    } on AnalysisException {
      // do not continue if this invocation is unfit for analysis
      return;
    }

    late bool constraintIssue;

    if (parentElement is ClassElement) {
      // ignore generics
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = element is MethodElement
          ? !dependencyMetadata.packageShape.containsMethodWithName(
              parentElement.name, metadata.identifierName)
          : !dependencyMetadata.packageShape.containsPropertyWithName(
              parentElement.name, metadata.identifierName);
    } else if (parentElement is ExtensionElement) {
      constraintIssue = element is MethodElement
          ? !dependencyMetadata.packageShape.containsExtensionMethodWithName(
              parentElement.name!, metadata.identifierName)
          : !dependencyMetadata.packageShape.containsExtensionPropertyWithName(
              parentElement.name!, metadata.identifierName);
    } else {
      // we may be looking at a top-level getter or setter
      // context.warning('Subclass ${parentElement.toString()} of parentElement (getter/setter) is not supported.');
      return;
    }

    issues[metadata.elementId] = constraintIssue
        ? PotentialLowerBoundConstraintIssue(
            dependencyPackageName: dependencyMetadata.packageName,
            constraint:
                context.dependencies[dependencyMetadata.packageName]!.version,
            currentVersion:
                context.findInstalledVersion(dependencyMetadata.packageName),
            lowestVersion:
                Version.parse(dependencyMetadata.packageShape.version),
            identifier: metadata.identifierName,
            parentName: parentElement.name!,
            kind: element.kind.toKind(),
            parentKind: parentElement.kind.toParentKind(),
            references: [metadata.span],
          )
        : null;
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // an access of an object property
    super.visitPropertyAccess(node);

    // the definition of the symbol being analysed, and its parent (where applicable)
    late final Element element;
    late final Element parentElement;

    if (node.propertyName.staticElement == null) {
      // we cannot statically resolve what was invoked
      return;
    }
    element = node.propertyName.staticElement!;

    late final IdentifierMetadata metadata;
    late final IdentifierDependencyMetadata dependencyMetadata;
    try {
      metadata = processIdentifier(node.propertyName, element: element);
      if (element.enclosingElement3 is ExtensionElement) {
        parentElement = element.enclosingElement3!;
      } else {
        parentElement = node.realTarget.staticType?.element2! ??
            (node.realTarget as Identifier).staticElement!;
      }
      dependencyMetadata = identifyDependencyName(element: parentElement);
    } on AnalysisException {
      // do not continue if this invocation is unfit for analysis
      return;
    }

    late bool constraintIssue;

    // differentiate between class methods and top-level functions
    if (parentElement is ClassElement) {
      // ignore generics
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = element is MethodElement
          ? !dependencyMetadata.packageShape.containsMethodWithName(
              parentElement.name, metadata.identifierName)
          : !dependencyMetadata.packageShape.containsPropertyWithName(
              parentElement.name, metadata.identifierName);
    } else if (parentElement is ExtensionElement) {
      // ignore generics
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = element is MethodElement
          ? !dependencyMetadata.packageShape.containsExtensionMethodWithName(
              parentElement.name!, metadata.identifierName)
          : !dependencyMetadata.packageShape.containsExtensionPropertyWithName(
              parentElement.name!, metadata.identifierName);
    } else {
      // context.warning('Subclass ${parentElement.toString()} of parentElement (method/function) is not supported.');
      return;
    }

    issues[metadata.elementId] = constraintIssue
        ? PotentialLowerBoundConstraintIssue(
      dependencyPackageName: dependencyMetadata.packageName,
            constraint:
                context.dependencies[dependencyMetadata.packageName]!.version,
            currentVersion:
                context.findInstalledVersion(dependencyMetadata.packageName),
            lowestVersion:
                Version.parse(dependencyMetadata.packageShape.version),
            identifier: metadata.identifierName,
            parentName: parentElement.name!,
            kind: element.kind.toKind(),
            parentKind: parentElement.kind.toParentKind(),
            references: [metadata.span],
          )
        : null;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // an invocation of a top-level function or a class method
    super.visitMethodInvocation(node);

    // the definition of the symbol being analysed, and its parent (where applicable)
    late final Element element;
    late final Element parentElement;

    if (node.methodName.staticElement == null) {
      // we cannot statically resolve what was invoked
      return;
    }
    element = node.methodName.staticElement!;

    late final IdentifierMetadata metadata;
    late final IdentifierDependencyMetadata dependencyMetadata;
    try {
      metadata = processIdentifier(node.methodName, element: element);
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
      dependencyMetadata = identifyDependencyName(element: parentElement);
    } on AnalysisException {
      // do not continue if this invocation is unfit for analysis
      return;
    }

    late bool constraintIssue;

    // differentiate between class methods and top-level functions
    if (parentElement is ClassElement) {
      // ignore generics
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = !dependencyMetadata.packageShape
          .containsMethodWithName(parentElement.name, metadata.identifierName);
    } else if (parentElement is CompilationUnitElement) {
      constraintIssue = !dependencyMetadata.packageShape
          .containsFunctionWithName(metadata.identifierName);
    } else if (parentElement is ExtensionElement) {
      // ignore generics
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = !dependencyMetadata.packageShape
          .containsExtensionMethodWithName(
              parentElement.name!, metadata.identifierName);
    } else {
      // context.warning('Subclass ${parentElement.toString()} of parentElement (method/function) is not supported.');
      return;
    }

    issues[metadata.elementId] = constraintIssue
        ? PotentialLowerBoundConstraintIssue(
            dependencyPackageName: dependencyMetadata.packageName,
            constraint:
                context.dependencies[dependencyMetadata.packageName]!.version,
            currentVersion:
                context.findInstalledVersion(dependencyMetadata.packageName),
            lowestVersion:
                Version.parse(dependencyMetadata.packageShape.version),
            identifier: metadata.identifierName,
            parentName: element.kind == ElementKind.FUNCTION
                ? null
                : parentElement.name!,
            kind: element.kind.toKind(),
            parentKind: element.kind == ElementKind.FUNCTION
                ? null
                : parentElement.kind.toParentKind(),
            references: [metadata.span],
          )
        : null;
  }
}

class IdentifierDependencyMetadata {
  final String packageName;
  final PackageShape packageShape;

  IdentifierDependencyMetadata({
    required this.packageName,
    required this.packageShape,
  });
}

class IdentifierMetadata {
  final SourceSpan span;
  final int elementId;
  final String identifierName;

  IdentifierMetadata({
    required this.span,
    required this.elementId,
    required this.identifierName,
  });
}
