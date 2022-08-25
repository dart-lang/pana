import 'package:analyzer/dart/element/element.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:pana/src/package_analysis/shapes_ext.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';

class PotentialLowerBoundConstraintIssue {
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

  /// The [ElementKind] of the [Element] corresponding to the missing
  /// [identifier], one of [ElementKind.FUNCTION], [ElementKind.METHOD],
  /// [ElementKind.GETTER], [ElementKind.SETTER].
  final ElementKind kind;

  /// The [ElementKind] of the parent [Element] of the missing [identifier],
  /// [parentName], one of [ElementKind.CLASS], [ElementKind.EXTENSION], or null
  /// if [identifier] is not a member of a class/extension.
  final ElementKind? parentKind;

  /// List of locations in the analyzed source code where [identifier] was referenced.
  final List<SourceSpan> references;

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

  PotentialLowerBoundConstraintIssue({
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
