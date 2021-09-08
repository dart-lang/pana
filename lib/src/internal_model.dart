// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'internal_model.g.dart';

/// The json output from `dart pub outdated --json`.
@JsonSerializable()
class Outdated {
  final List<OutdatedPackage> packages;

  Outdated(this.packages);

  static Outdated fromJson(Map<String, dynamic> json) =>
      _$OutdatedFromJson(json);

  Map<String, dynamic> toJson() => _$OutdatedToJson(this);
}

@JsonSerializable()
class OutdatedPackage {
  final String package;
  final VersionDescriptor? upgradable;
  final VersionDescriptor? latest;

  OutdatedPackage(this.package, this.upgradable, this.latest);

  static OutdatedPackage fromJson(Map<String, dynamic> json) =>
      _$OutdatedPackageFromJson(json);

  Map<String, dynamic> toJson() => _$OutdatedPackageToJson(this);
}

@JsonSerializable()
class VersionDescriptor {
  final String version;

  VersionDescriptor(this.version);

  static VersionDescriptor fromJson(Map<String, dynamic> json) =>
      _$VersionDescriptorFromJson(json);

  Map<String, dynamic> toJson() => _$VersionDescriptorToJson(this);
}

@JsonSerializable()
class CodeProblem implements Comparable<CodeProblem> {
  /// The errors which don't block platform classification.
  static const _platformNonBlockerTypes = <String>[
    'STATIC_TYPE_WARNING',
    'STATIC_WARNING',
  ];

  static const _platformNonBlockerCodes = <String>[
    'ARGUMENT_TYPE_NOT_ASSIGNABLE',
    'STRONG_MODE_COULD_NOT_INFER',
    'STRONG_MODE_INVALID_CAST_FUNCTION_EXPR',
    'STRONG_MODE_INVALID_CAST_NEW_EXPR',
    'STRONG_MODE_INVALID_METHOD_OVERRIDE',
  ];

  final String severity;
  final String errorType;
  final String errorCode;

  final String file;
  final int line;
  final int col;
  final int length;
  final String description;

  CodeProblem({
    required this.severity,
    required this.errorType,
    required this.errorCode,
    required this.description,
    required this.file,
    required this.line,
    required this.col,
    required this.length,
  });

  factory CodeProblem.fromJson(Map<String, dynamic> json) =>
      _$CodeProblemFromJson(json);

  Map<String, dynamic> toJson() => _$CodeProblemToJson(this);

  bool get isError => severity.toUpperCase() == 'ERROR';

  bool get isWarning => severity.toUpperCase() == 'WARNING';

  bool get isInfo => severity.toUpperCase() == 'INFO';

  /// `true` iff [isError] is `true` and [errorType] is not safe to ignore for
  /// platform classification.
  bool get isPlatformBlockingError =>
      isError &&
      !_platformNonBlockerTypes.contains(errorType) &&
      !_platformNonBlockerCodes.contains(errorCode);

  @override
  int compareTo(CodeProblem other) {
    var myVals = _values;
    var otherVals = other._values;
    for (var i = 0; i < myVals.length; i++) {
      var compare = (_values[i] as Comparable).compareTo(otherVals[i]);

      if (compare != 0) {
        return compare;
      }
    }

    assert(this == other);

    return 0;
  }

  int severityCompareTo(CodeProblem other) {
    if (isError && !other.isError) return -1;
    if (!isError && other.isError) return 1;
    if (isWarning && !other.isWarning) return -1;
    if (!isWarning && other.isWarning) return 1;
    if (isInfo && !other.isInfo) return -1;
    if (!isInfo && other.isInfo) return 1;
    return compareTo(other);
  }

  @override
  int get hashCode => Object.hashAll(_values);

  @override
  bool operator ==(Object other) {
    if (other is CodeProblem) {
      var myVals = _values;
      var otherVals = other._values;
      for (var i = 0; i < myVals.length; i++) {
        if (myVals[i] != otherVals[i]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  List<Object> get _values =>
      [file, line, col, severity, errorType, errorCode, description];
}
