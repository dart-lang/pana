import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:collection/collection.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';

import 'common.dart';

/// Given a target *dummy* package and the summaries of the target's dependencies
/// at their lower bound, analyze the target package and return a List of any
/// found issues - where a symbol usage cannot be found in the relevant
/// dependency's PackageShape
Future<List<LowerBoundConstraintIssue>> lowerBoundConstraintAnalysis({
  required PackageAnalysisContext context,
  required Map<String, PackageShape> dependencySummaries,
}) async {
  var astVisitor = _LowerBoundConstraintVisitor(
    context: context,
    dependencySummaries: dependencySummaries,
  );

  final libPath = path.join(context.targetPackagePath!, 'lib');
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
          'Attempting to get a resolved unit resulted in an invalid result.');
    }
  }

  return astVisitor.issues.values.whereNotNull().toList();
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
  late Element enclosingElement;

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

    final tryPackageName = packageFromLibraryUri(element.library!.identifier);
    // if the defining package isn't a HostedDependency of the target, then
    // this symbol cannot be analyzed
    if (tryPackageName == null ||
        !context.targetDependencies.keys.contains(tryPackageName)) {
      throw AnalysisException(
          'The defining package is not a HostedDependency of the target package.');
    }
    packageName = tryPackageName;

    if (!dependencySummaries.keys.contains(packageName)) {
      context.warning('No summary for $packageName found.');
      throw AnalysisException('No summary was found for the defining package.');
    }
    dependencyShape = dependencySummaries[packageName]!;

    // assume that element is not a library, so enclosingElement will never be null
    enclosingElement = element.enclosingElement!;

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

    // a PrefixedIdentifier does not necessarily represent a property access
    if (element is! PropertyAccessorElement) {
      return;
    }

    try {
      processIdentifier(node.identifier);
    } on AnalysisException {
      // do not continue if this invocation is unfit for analysis
      return;
    }

    late bool constraintIssue;

    if (enclosingElement is ClassElement) {
      // ignore generics
      if ((enclosingElement as ClassElement).typeParameters.isNotEmpty) {
        return;
      }
      // does this dependency's PackageShape have a class whose name matches
      // that of enclosingElement, and does this class have a property with a matching name?
      // initially assume there is an issue and look for classes with the correct property
      constraintIssue = true;
      final classesMatchingName = dependencyShape.classes
          .where((thisClass) => thisClass.name == enclosingElement.name);
      for (final thisClass in classesMatchingName) {
        if ([
          ...thisClass.getters,
          ...thisClass.setters,
          ...thisClass.staticGetters,
          ...thisClass.staticSetters,
        ].any((property) => property.name == symbolName)) {
          constraintIssue = false;
          break;
        }
      }
    } else {
      // we may be looking at a top-level getter or setter, or that of an extension
      // context.warning('Subclass ${enclosingElement.toString()} of enclosingElement (getter/setter) is not supported.');
      return;
    }

    issues[elementId] = constraintIssue
        ? LowerBoundConstraintIssue(
            dependencyPackageName: packageName,
            constraint: context.targetDependencies[packageName]!.version,
            currentVersion: getInstalledVersion(
              context: context,
              dependencyName: packageName,
            ),
            lowestVersion: Version.parse(dependencyShape.version),
            identifier: symbolName,
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

    try {
      processIdentifier(node.methodName);
    } on AnalysisException {
      // do not continue if this invocation is unfit for analysis
      return;
    }

    late bool constraintIssue;

    // differentiate between class methods and top-level functions
    if (enclosingElement is ClassElement) {
      // ignore generics
      if ((enclosingElement as ClassElement).typeParameters.isNotEmpty) {
        return;
      }
      // does this dependency's PackageShape have a class whose name matches
      // that of enclosingElement, and does this class have a method with a matching name?
      // initially assume there is an issue and look for classes with the correct method
      constraintIssue = true;
      final classesMatchingName = dependencyShape.classes
          .where((thisClass) => thisClass.name == enclosingElement.name);
      for (final thisClass in classesMatchingName) {
        if ([...thisClass.methods, ...thisClass.staticMethods]
            .any((method) => method.name == symbolName)) {
          constraintIssue = false;
          break;
        }
      }
    } else if (enclosingElement is CompilationUnitElement) {
      // does this top-level function exist in this dependency's PackageShape?
      constraintIssue = !dependencyShape.functions
          .map((function) => function.name)
          .contains(symbolName);
    } else {
      // we may be looking at an extension method
      // context.warning('Subclass ${enclosingElement.toString()} of enclosingElement (method/function) is not supported.');
      return;
    }

    issues[elementId] = constraintIssue
        ? LowerBoundConstraintIssue(
      dependencyPackageName: packageName,
            constraint: context.targetDependencies[packageName]!.version,
            currentVersion: getInstalledVersion(
              context: context,
              dependencyName: packageName,
            ),
            lowestVersion: Version.parse(dependencyShape.version),
            identifier: symbolName,
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

  // TODO: should we record the kind of this identifier (class, method, function, etc)?
  /// The name of the identifier that is referenced in source code, and which is
  /// available in the latest version of [dependencyPackageName], but not in
  /// version [lowestVersion], which is allowed by the lower-bound dependency
  /// constraint [constraint].
  final String identifier;

  /// List of locations in the analyzed source code where [identifier] was referenced.
  final List<SourceSpan> references;

  @override
  String toString() {
    return 'LowerBoundConstraintIssue{dependencyPackageName: $dependencyPackageName, constraint: $constraint, currentVersion: $currentVersion, lowestVersion: $lowestVersion, identifier: $identifier}';
  }

  LowerBoundConstraintIssue({
    required this.dependencyPackageName,
    required this.constraint,
    required this.currentVersion,
    required this.lowestVersion,
    required this.identifier,
    required this.references,
  });
}
