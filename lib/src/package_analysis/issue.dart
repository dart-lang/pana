// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:pana/src/package_analysis/shapes_ext.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';

import 'kind.dart';

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

  /// The [Kind] of the [Element] corresponding to the missing [identifier].
  final Kind kind;

  /// The [ParentKind] of the parent [Element] of the missing [identifier],
  /// [parentName].
  final ParentKind? parentKind;

  /// List of locations in the analyzed source code where [identifier] was referenced.
  final List<SourceSpan> references;

  /// Does [package] (some version of the defining dependency) contain [identifier]?
  /// If [classNameAlias] is specified, it will be used instead of [parentName].
  bool identifierExistsInPackage({
    required PackageShape package,
    String? classNameAlias,
  }) {
    switch (kind) {
      case Kind.function:
        return package.containsFunctionWithName(identifier);

      case Kind.method:
        switch (parentKind) {
          case ParentKind.enumKind:
          case ParentKind.classKind:
            return package.containsMethodWithName(
              classNameAlias ?? parentName!,
              identifier,
            );
          case ParentKind.extensionKind:
            return package.containsExtensionMethodWithName(
              parentName!,
              identifier,
            );
          case null:
            throw StateError(
                'Identifier is a method, parentKind is unexpectedly null.');
        }

      case Kind.getter:
        switch (parentKind) {
          case ParentKind.enumKind:
          case ParentKind.classKind:
            return package.containsGetterWithName(
              classNameAlias ?? parentName!,
              identifier,
            );
          case ParentKind.extensionKind:
            return package.containsExtensionGetterWithName(
              parentName!,
              identifier,
            );
          case null:
            throw StateError(
                'Identifier is a getter, parentKind is unexpectedly null.');
        }

      case Kind.setter:
        switch (parentKind) {
          case ParentKind.enumKind:
          case ParentKind.classKind:
            return package.containsSetterWithName(
              classNameAlias ?? parentName!,
              identifier,
            );
          case ParentKind.extensionKind:
            return package.containsExtensionSetterWithName(
              parentName!,
              identifier,
            );
          case null:
            throw StateError(
                'Identifier is a setter, parentKind is unexpectedly null.');
        }
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
