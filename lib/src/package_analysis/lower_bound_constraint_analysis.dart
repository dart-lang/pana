import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'common.dart';

/// Given a target package and its dependencies (at their lower bound),
/// analyze the target package and return a List of any found issues - where a
/// symbol usage cannot be found in the relevant dependency's PackageShape
Future<List<LowerBoundConstraintIssue>> reportIssues({
  required PackageAnalysisContext packageAnalysisContext,
  required String packageLocation,
  required String? rootPackageName,
  required Map<String, PackageShape> dependencySummaries,
  required Map<String, HostedDependency> targetDependencies,
  required Map<String, Version> dependencyInstalledVersions,
}) async {
  var collection = packageAnalysisContext.analysisContextCollection;
  var astVisitor = MyAstVisitor(
    rootPackage: rootPackageName,
    warning: packageAnalysisContext.warning,
    dependencySummaries: dependencySummaries,
    targetDependencies: targetDependencies,
    dependencyInstalledVersions: dependencyInstalledVersions,
  );

  for (var context in collection.contexts) {
    final session = context.currentSession;

    for (var filePath in context.contextRoot.analyzedFiles()) {
      // match [packageLocation]/lib/*.dart
      if (!(path.isWithin(path.join(packageLocation, 'lib'), filePath) &&
          path.extension(filePath) == '.dart')) {
        continue;
      }

      var result = await session.getResolvedUnit(filePath);
      if (result is ResolvedUnitResult) {
        astVisitor.visitCompilationUnit(result.unit);
      } else {
        packageAnalysisContext.warning(
            'Attempting to get a resolved unit resulted in an invalid result.');
      }
    }
  }

  return astVisitor.issues.values.whereNotNull().toList();
}

class MyAstVisitor extends GeneralizingAstVisitor {
  /// Maps from [Element.id] to either [LowerBoundConstraintIssue] if the lower
  /// bound constraint on [LowerBoundConstraintIssue.dependencyPackageName] is
  /// too low, making [Element] when the lowest allowed version
  /// [LowerBoundConstraintIssue.lowestVersion] is used, or null otherwise.
  final Map<int, LowerBoundConstraintIssue?> issues = {};

  /// The name of the package being analysed. Invocations corresponding to
  /// definitions within this package will be ignored.
  final String? rootPackage;

  /// The summaries of each of the dependencies of the target package.
  final Map<String, PackageShape> dependencySummaries;

  /// The dependencies of the target package, as parsed from its pubspec.
  final Map<String, HostedDependency> targetDependencies;

  /// The versions of the dependencies of the target package, as installed.
  final Map<String, Version> dependencyInstalledVersions;

  /// Log a warning that something unexpected happened.
  final void Function(String message) warning;

  MyAstVisitor({
    required this.rootPackage,
    required this.warning,
    required this.dependencySummaries,
    required this.targetDependencies,
    required this.dependencyInstalledVersions,
  });

  // TODO: consider FunctionReference, PropertyAccess

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // an invocation of a top-level function or a class method
    super.visitMethodInvocation(node);

    final element = node.methodName.staticElement;

    if (element == null) {
      warning(
          'Element associated with identifier ${node.methodName.name} could not be resolved.');
      return;
    }

    final elementId = element.id;
    final libraryUri = element.library!.identifier;
    final symbolName = element.name!;
    final packageName = packageFromLibraryUri(libraryUri);

    if (issues.containsKey(elementId)) {
      if (issues[elementId] == null) {
        // if there is no problem with this element, return immediately
        return;
      } else {
        // we have seen this symbol before
        // TODO: handle this case by adding a reference to issues[elementId]
        return;
      }
    }

    // if the name of the package can't be resolved,
    // or it is the same as the name of the target package (or flutter)
    // then this symbol cannot be analysed
    if (packageName == null ||
        packageName == rootPackage ||
        packageName == 'flutter') {
      return;
    }

    if (!dependencySummaries.keys.contains(packageName)) {
      warning('No summary for $packageName found.');
      return;
    }

    final dependencyShape = dependencySummaries[packageName]!;
    final enclosingElement = element.enclosingElement;
    bool? constraintIssue;

    // differentiate between class methods and top-level functions
    if (enclosingElement is ClassElement) {
      // does this dependency's PackageShape have a class whose name matches that of enclosingElement,
      // and does this class have a method with a matching name?
      // TODO: look though multiple classes
      final classShape = dependencyShape.classes.firstWhereOrNull(
          (thisClass) => thisClass.name == enclosingElement.name);
      if (classShape != null &&
          classShape.methods.any((method) => method.name == symbolName)) {
        constraintIssue = false;
      } else {
        constraintIssue = true;
      }
    } else if (enclosingElement is CompilationUnitElement) {
      // does this top-level function exist in this the dependency's PackageShape?
      if (dependencyShape.functions
          .map((function) => function.name)
          .contains(symbolName)) {
        constraintIssue = false;
      } else {
        constraintIssue = true;
      }
    } else {
      warning(
          'Failed to resolve subclass of enclosingElement ${enclosingElement.toString()}.');
    }

    switch (constraintIssue) {
      case true:
        {
          // TODO: remove debug prints above
          issues[elementId] = LowerBoundConstraintIssue(
              dependencyPackageName: packageName,
              constraint: targetDependencies[packageName]!.version,
              currentVersion: dependencyInstalledVersions[packageName]!,
              lowestVersion: Version.parse(dependencyShape.version),
              identifier: symbolName);
        }
        break;

      case false:
        {
          issues[elementId] = null;
        }
        break;

      default:
        break;
    }
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

  // TODO: implement this
  // List of locations in the analyzed source code where [identifier] was referenced.
  // final List<SourceSpan> references;

  LowerBoundConstraintIssue({
    required this.dependencyPackageName,
    required this.constraint,
    required this.currentVersion,
    required this.lowestVersion,
    required this.identifier,
  });
}
