// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';

import 'common.dart';
import 'issue.dart';
import 'kind.dart';
import 'shapes.dart';
import 'summary.dart';

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
    // Attempt to download the latest version of the target package (the package
    // being searched for issues) using a dummy package (a locally-created
    // package with only a single dependency on [targetName] and a constraint
    // pinning it to an exact version).
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
    // It is probable that version solving failed.
    throw AnalysisException(
        'Failed to download target package $targetName with error code ${exception.errorCode}: ${exception.message}');
  }

  // Create analysis session for analysing the target package.
  final collection = AnalysisContextCollection(includedPaths: [dummyPath]);
  final context = PackageAnalysisContext(
    session: collection.contextFor(dummyPath).currentSession,
    packagePath: dummyPath,
    targetPackageName: targetName,
    warningSink: stderr.nonBlocking,
  );

  // If there are no dependencies, there will be no issues.
  if (context.dependencies.isEmpty) {
    return [];
  }

  final dependencySummaries = <String, PackageShape>{};

  // Iterate over each dependency of the target package and for each one:
  // - Determine the installed (current/actual) version of the dependency.
  // - Download the minimum allowed version of the dependency in a different directory.
  // - Produce a summary of the minimum allowed version of the dependency.
  for (final dependencyEntry in context.dependencies.entries) {
    final dependencyName = dependencyEntry.key;
    final dependencyInstalledVersion =
        context.findInstalledVersion(dependencyName);
    final dependencyVersionConstraint = dependencyEntry.value.version;
    final dependencyDestination =
        path.join(dependencyFolder, '${dependencyName}_dummy');

    // Find all available versions of this dependency.
    final allVersions = await fetchSortedPackageVersionList(
      packageName: dependencyName,
      cachePath: cachePath,
      pubHostedUrl: pubHostedUrl,
    );

    // Determine the smallest version of this dependency for which version
    // solving passes, but which is not the installed version (issues will never
    // be found in this way).
    Version? minVersion;
    // Iterate over the allowed versions in ascending order.
    for (final smallVersion in allVersions.where((version) =>
        dependencyVersionConstraint.allows(version) &&
        version != dependencyInstalledVersion)) {
      // Attempt to download this version of the dependency.
      try {
        await fetchUsingDummyPackage(
          name: dependencyName,
          version: smallVersion.toString(),
          destination: dependencyDestination,
          pubHostedUrl: pubHostedUrl,
          pubCachePath: pubCachePath,
        );
      } on ProcessException {
        // If version solving fails with this version of the dependency,
        // try again with a higher version.
        await Directory(dependencyDestination).delete(recursive: true);
        continue;
      }

      // Version solving passed, so this is the minimum working version of this dependency.
      minVersion = smallVersion;
      break;
    }

    if (minVersion == null) {
      // No version of this dependency (other than the installed version) passed
      // version solving.
      continue;
    }

    // Create analysis session for producing a summary of this dependency.
    final collection = AnalysisContextCollection(includedPaths: [
      dependencyDestination,
    ]);
    final dependencyPackageAnalysisContext = PackageAnalysisContext(
      session: collection.contextFor(dependencyDestination).currentSession,
      packagePath: dependencyDestination,
      warningSink: stderr.nonBlocking,
    );

    // Produce a summary of the minimum allowed version of this dependency and store it.
    dependencySummaries[dependencyName] = await summarizePackage(
      context: dependencyPackageAnalysisContext,
      packagePath:
          dependencyPackageAnalysisContext.findPackagePath(dependencyName),
      normalize: false,
    );
  }

  final astVisitor = _LowerBoundConstraintVisitor(
    context: context,
    dependencySummaries: dependencySummaries,
  );

  // The location of the source code of the target package.
  final libPath = path.join(context.packagePath, 'lib');
  final libFolder = context.folder(libPath);

  // Retrieve the paths of all the `.dart` library files comprising the target
  // package via the resourceProvider , namely `.dart` files in `./lib`.
  final dartLibFiles = allFilesInFolder(libFolder)
      .where((file) => path.extension(file.path) == '.dart')
      .map((file) => file.path)
      .sorted();

  for (final filePath in dartLibFiles) {
    // For each `.dart` library file, produce a resolved [CompilationUnit]
    // and visit the AST, looking for invocations of symbols which are defined
    // in one of the direct dependencies of the target package, but which are
    // not present in the corresponding PackageShape summary.
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

  // Eliminate false positive issues.
  for (final possibleIssue in astVisitor.issues.values.whereNotNull()) {
    // CURRENT DEPENDENCY VERSION CHECK:
    // Eliminate false positives by checking whether the 'missing' identifier
    // is present in the current/installed version of the dependency.
    // If it isn't, then we have not been able to detect a difference between
    // the lower bound version and the current version, and the issue might be a
    // false positive.

    // Produce a summary of the currently-installed version of the dependency
    // defining the 'missing' identifier.
    if (!installedDependencySummaries
        .containsKey(possibleIssue.dependencyPackageName)) {
      installedDependencySummaries[possibleIssue.dependencyPackageName] =
          await summarizePackage(
        context: context,
        packagePath:
            context.findPackagePath(possibleIssue.dependencyPackageName),
        normalize: false,
      );
    }

    // If this identifier does not exist in the current version of the defining
    // dependency, this might be a false positive.
    if (!possibleIssue.identifierExistsInPackage(
      package:
          installedDependencySummaries[possibleIssue.dependencyPackageName]!,
    )) {
      continue;
    }

    // TYPEDEF CHECK:
    // Look at the typedefs that are in scope/imported at the reference sites to
    // see if checking for an alias of [possibleIssue.className] may reveal a
    // false positive.
    // For example, if there are typedefs in scope at each reference site, which
    // give an alias to a class, this class will have two aliases, between which
    // the visitor cannot distinguish. We will need to ensure that the identifier
    // still cannot be found, even after using the other available class alias.

    // Ensure we are dealing with a class member and that issue.className != null.
    if (possibleIssue.kind == Kind.function) {
      // We cannot perform the typedef check on this issue.
      issues.add(possibleIssue);
      continue;
    }

    // The names of the aliases which could have been used, for each reference site.
    final possibleParentNames = <List<String>>[];
    for (final reference in possibleIssue.references) {
      final typedefsHere = await context.findTypedefs(reference.sourceUrl!);
      if (typedefsHere[possibleIssue.parentIdentifier!] != null) {
        possibleParentNames.add(typedefsHere[possibleIssue.parentIdentifier!]!);
      }
    }

    // The names of the aliases which could have been used at ALL reference sites.
    final commonParentNames = possibleParentNames.fold<Set<String>>(
        possibleParentNames.isEmpty
            ? <String>{}
            : possibleParentNames.first.toSet(),
        (a, b) => a.intersection(b.toSet()));

    // If replacing the parent class name with any one of the found aliases
    // results in the identifier being found in the dependency summary,
    // then we have a false positive because a typedef alias was used.
    if (commonParentNames
        .any((classNameAlias) => possibleIssue.identifierExistsInPackage(
              package:
                  dependencySummaries[possibleIssue.dependencyPackageName]!,
              classNameAlias: classNameAlias,
            ))) {
      continue;
    }

    // Neither the current dependency version check nor the typedef check could
    // reveal a false positive.
    issues.add(possibleIssue);
  }

  return issues;
}

class _LowerBoundConstraintVisitor extends GeneralizingAstVisitor {
  /// The [PackageAnalysisContext] corresponding to the package being analyzed.
  final PackageAnalysisContext context;

  /// Maps from [Element.id] to one of:
  /// - [PotentialLowerBoundConstraintIssue], if there is a lower bound
  /// constraint issue associated to the [Element] with this [Element.id]
  /// - `null`, if the [Element] with this [Element.id] was visited and no lower
  /// bound constraint issue was discovered
  final Map<int, PotentialLowerBoundConstraintIssue?> issues = {};

  /// Maps from the [String] corresponding to the name of one of the direct
  /// dependencies of the target package to the [PackageShape] public API
  /// summary of this dependency at its lowest allowed version.
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
    // If the defining package isn't a [HostedDependency] of the target (a
    // direct dependency published to pub.dev), then this symbol cannot be analyzed.
    if (tryPackageName == null ||
        !context.dependencies.keys.contains(tryPackageName)) {
      throw AnalysisException(
          'The defining package is not a hosted dependency of the target package.');
    }

    // If we do not have a public API summary of the target package, this symbol
    // cannot be analyzed.
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
    final uri =
        (identifier.root as CompilationUnit).declaredElement!.source.uri;
    final identifierMetadata = IdentifierMetadata(
      span: SourceFile.fromString(
        context.readFile(context.uriToPath(uri)!),
        url: uri,
      ).span(identifier.offset, identifier.end),
      elementId: element.id,
      // If the element is a getter or a setter, extract just the variable name.
      identifierName: element is PropertyAccessorElement
          ? element.variable.name
          : element.name!,
    );

    // If we have seen this symbol before, we need to do no further analysis.
    if (issues.containsKey(identifierMetadata.elementId)) {
      // If we have seen this symbol before and there is an issue with it
      // (then `issues[identifierMetadata.elementId] != null`), add this
      // usage/invocation to its list of references. Otherwise,
      // `issues[identifierMetadata.elementId] == null` and we do nothing.
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
    super.visitCompilationUnit(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // An access of an object property.
    super.visitPrefixedIdentifier(node);

    // The definition of the symbol being analysed, and its parent (where applicable).
    late final Element element;
    late final Element parentElement;

    final parentNode = node.parent;
    if (node.staticElement != null) {
      element = node.staticElement!;
    } else if (parentNode is AssignmentExpression &&
        parentNode.writeElement != null) {
      // This special case is needed to retrieve the PropertyAccessorElement for a setter.
      element = parentNode.writeElement!;
    } else if (node.identifier.staticElement != null) {
      element = node.identifier.staticElement!;
    } else {
      // Cannot statically resolve what was invoked.
      return;
    }

    if (element is! PropertyAccessorElement && element is! MethodElement) {
      // A [PrefixedIdentifier] does not necessarily represent a property access.
      return;
    }

    late final IdentifierMetadata metadata;
    late final IdentifierDependencyMetadata dependencyMetadata;
    try {
      metadata = processIdentifier(node.identifier, element: element);
      if (element.enclosingElement3 is ExtensionElement) {
        parentElement = element.enclosingElement3!;
      } else if (node.prefix.staticType is FunctionType) {
        // Do not allow the parent to be a [Function].
        // This breaks the assertion `node.prefix.staticType?.element2 != null`.
        return;
      } else {
        parentElement =
            node.prefix.staticType?.element2! ?? node.prefix.staticElement!;
      }
      dependencyMetadata = identifyDependencyName(element: parentElement);
    } on AnalysisException {
      // Do not continue if this invocation is unfit for analysis.
      return;
    }

    late bool constraintIssue;

    if (parentElement is ClassElement) {
      // Ignore generics.
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
      // This node may be an invocation of a top-level getter or setter.
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
            parentIdentifier: parentElement.name!,
            kind: element.kind.toKind(),
            parentKind: parentElement.kind.toParentKind(),
            references: [metadata.span],
          )
        : null;
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // An access of an object property.
    super.visitPropertyAccess(node);

    // The definition of the symbol being analysed, and its parent (where applicable).
    late final Element element;
    late final Element parentElement;

    if (node.parent is CommentReference) {
      // Do not perform analysis on invocations inside comment references.
      return;
    } else if (node.parent is CompoundAssignmentExpression &&
        (node.parent as CompoundAssignmentExpression).writeElement != null &&
        node.parent?.parent is CascadeExpression) {
      // We need to go up one level up in the AST if an assignment is happening in cascade notation.
      element = (node.parent as CompoundAssignmentExpression).writeElement!;
    } else if (node.propertyName.staticElement != null) {
      element = node.propertyName.staticElement!;
    } else {
      // Cannot statically resolve what was invoked.
      return;
    }

    late final IdentifierMetadata metadata;
    late final IdentifierDependencyMetadata dependencyMetadata;
    try {
      metadata = processIdentifier(node.propertyName, element: element);
      if (element.enclosingElement3 is ExtensionElement) {
        parentElement = element.enclosingElement3!;
      } else if (node.realTarget.staticType is FunctionType) {
        // Do not allow the parent to be a [Function].
        // This breaks the assertion `node.realTarget.staticType?.element2 != null`.
        return;
      } else {
        parentElement = node.realTarget.staticType?.element2! ??
            (node.realTarget is ExtensionOverride
                    ? (node.realTarget as ExtensionOverride).extensionName
                    : node.realTarget as Identifier)
                .staticElement!;
      }
      dependencyMetadata = identifyDependencyName(element: parentElement);
    } on AnalysisException {
      // Do not continue if this invocation is unfit for analysis.
      return;
    }

    late bool constraintIssue;

    // Differentiate between class methods and top-level functions.
    if (parentElement is ClassElement) {
      // Ignore generics.
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = element is MethodElement
          ? !dependencyMetadata.packageShape.containsMethodWithName(
              parentElement.name, metadata.identifierName)
          : !dependencyMetadata.packageShape.containsPropertyWithName(
              parentElement.name, metadata.identifierName);
    } else if (parentElement is ExtensionElement) {
      // Ignore generics.
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = element is MethodElement
          ? !dependencyMetadata.packageShape.containsExtensionMethodWithName(
              parentElement.name!, metadata.identifierName)
          : !dependencyMetadata.packageShape.containsExtensionPropertyWithName(
              parentElement.name!, metadata.identifierName);
    } else {
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
            parentIdentifier: parentElement.name!,
            kind: element.kind.toKind(),
            parentKind: parentElement.kind.toParentKind(),
            references: [metadata.span],
          )
        : null;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // An invocation of a top-level function or a class method.
    super.visitMethodInvocation(node);

    // The definition of the symbol being analysed, and its parent (where applicable).
    late final Element element;
    late final Element parentElement;

    if (node.methodName.staticElement == null) {
      // Cannot statically resolve what was invoked.
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
      } else if (node.parent is CascadeExpression &&
          (node.parent as CascadeExpression).target.staticType != null) {
        parentElement =
            (node.parent as CascadeExpression).target.staticType!.element2!;
      } else if (node.realTarget == null ||
          node.realTarget!.staticType is FunctionType) {
        // Do not allow the parent to be a [Function].
        // This breaks the assertion `node.realTarget!.staticType?.element2 != null`.
        return;
      } else {
        parentElement = node.realTarget!.staticType?.element2! ??
            (node.realTarget! as Identifier).staticElement!;
      }
      dependencyMetadata = identifyDependencyName(element: parentElement);
    } on AnalysisException {
      // Do not continue if this invocation is unfit for analysis.
      return;
    }

    late bool constraintIssue;

    // Differentiate between class methods and top-level functions.
    if (parentElement is ClassElement) {
      // Ignore generics.
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = !dependencyMetadata.packageShape
          .containsMethodWithName(parentElement.name, metadata.identifierName);
    } else if (parentElement is CompilationUnitElement) {
      constraintIssue = !dependencyMetadata.packageShape
          .containsFunctionWithName(metadata.identifierName);
    } else if (parentElement is ExtensionElement) {
      // Ignore generics.
      if (parentElement.typeParameters.isNotEmpty) {
        return;
      }
      constraintIssue = !dependencyMetadata.packageShape
          .containsExtensionMethodWithName(
              parentElement.name!, metadata.identifierName);
    } else {
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
            parentIdentifier: element.kind == ElementKind.FUNCTION
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
