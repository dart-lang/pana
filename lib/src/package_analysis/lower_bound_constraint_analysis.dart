import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:collection/collection.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:pana/src/package_analysis/shapes_ext.dart';
import 'package:pana/src/package_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';

import 'common.dart';

/// Given a context associated with a target package and the summaries of the
/// target's dependencies at their lower bound, analyze the target package and
/// return a List of any found issues - where a symbol usage cannot be found in
/// the relevant dependency's PackageShape.
Future<List<LowerBoundConstraintIssue>> lowerBoundConstraintAnalysis({
  required PackageAnalysisContext context,
  required Map<String, PackageShape> dependencySummaries,
}) async {
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
      if (typedefsHere[possibleIssue.className!] != null) {
        possibleParentNames.add(typedefsHere[possibleIssue.className!]!);
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
      context.warning('No summary for $packageName found.');
      throw AnalysisException('No summary was found for the defining package.');
    }
    dependencyShape = dependencySummaries[packageName]!;
  }

  /// Populate the various properties of this visitor based on information from
  /// this symbol, throwing an [AnalysisException] if the symbol does not need
  /// to be/cannot be analyzed.
  void processIdentifier(SimpleIdentifier identifier) {
    if (element.enclosingElement is ExtensionElement) {
      throw AnalysisException('Extensions are not yet supported.');
    }

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

  // TODO: we probably need visitPropertyAccess too
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
      parentElement =
          node.prefix.staticType?.element! ?? node.prefix.staticElement!;
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
    } else {
      // we may be looking at a top-level getter or setter, or that of an extension
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
            className: parentElement.name!,
            kind: element.kind,
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
      if (element is FunctionElement) {
        parentElement = element.enclosingElement!;
      } else if (node.parent is CascadeExpression) {
        // TODO: handle cascade notation
        return;
      } else if (node.target == null) {
        return;
      } else {
        parentElement = node.target!.staticType?.element! ??
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
      constraintIssue =
          !dependencyShape.containsNamedMethod(parentElement.name!, symbolName);
    } else if (parentElement is CompilationUnitElement) {
      constraintIssue = !dependencyShape.containsNamedFunction(symbolName);
    } else {
      // we may be looking at an extension method
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
            className: element.kind == ElementKind.FUNCTION
                ? null
                : parentElement.name!,
            kind: element.kind,
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

  /// The name of the enclosing class of the missing identifier, or null if
  /// [identifier] is not a class member.
  final String? className;

  // TODO: make the type of [identifierKind] an enum with only the supported [ElementKind]s?
  /// The kind of this identifier, one of [ElementKind.FUNCTION],
  /// [ElementKind.METHOD], [ElementKind.GETTER], [ElementKind.SETTER]
  final ElementKind kind;

  /// List of locations in the analyzed source code where [identifier] was referenced.
  final List<SourceSpan> references;

  /// Does [package] (some version of the defining dependency) contain [identifier]?
  /// If [classNameAlias] is specified, it will be used instead of [className].
  bool identifierExistsInPackage(
      {required PackageShape package, String? classNameAlias}) {
    switch (kind) {
      case ElementKind.FUNCTION:
        return package.containsFunctionWithName(identifier);

      case ElementKind.METHOD:
        return package.containsMethodWithName(
          classNameAlias ?? className!,
          identifier,
        );

      case ElementKind.GETTER:
        return package.containsGetterWithName(
          classNameAlias ?? className!,
          identifier,
        );

      case ElementKind.SETTER:
        return package.containsSetterWithName(
          classNameAlias ?? className!,
          identifier,
        );

      default:
        throw StateError('Unexpected ElementKind $kind.');
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
    required this.className,
    required this.kind,
    required this.references,
  });
}
