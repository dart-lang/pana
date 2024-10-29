// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

import 'model.dart';
import 'tag/_common.dart';
import 'tag/pana_tags.dart';
import 'tool/run_constrained.dart';

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

class AnalyzeToolResult {
  final List<CodeProblem>? items;
  final List<String> tags;
  final List<Explanation> explanations;
  final ToolException? toolError;

  AnalyzeToolResult({
    required this.items,
    required this.tags,
    required this.explanations,
  }) : toolError = null;

  AnalyzeToolResult.toolError(this.toolError)
      : items = null,
        tags = [PanaTags.hasError],
        explanations = [];

  bool get hasError => toolError != null;
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

/// The URL's parsed and queried status.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class UrlStatus {
  /// Whether the URL can be parsed and is valid.
  final bool isInvalid;

  /// Whether the URL uses HTTPS.
  final bool isSecure;

  /// Whether the URL exists and responds with an OK status code.
  final bool exists;

  UrlStatus({
    required this.isInvalid,
    required this.isSecure,
    required this.exists,
  });

  UrlStatus.invalid()
      : isInvalid = true,
        isSecure = false,
        exists = false;

  /// Returns a brief problem code that can be displayed when linking to it.
  /// Returns `null` when URL has no problem.
  String? getProblemCode() {
    if (isInvalid) return UrlProblemCodes.invalid;
    if (!isSecure) return UrlProblemCodes.insecure;
    if (!exists) return UrlProblemCodes.missing;
    return null;
  }

  static UrlStatus fromJson(Map<String, dynamic> json) =>
      _$UrlStatusFromJson(json);

  Map<String, dynamic> toJson() => _$UrlStatusToJson(this);
}

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class VerifiedRepository {
  final Repository? repository;
  final String? contributingUrl;
  final String? verificationFailure;
  final RepositoryVerificationStatus status;

  VerifiedRepository({
    this.repository,
    this.contributingUrl,
    this.verificationFailure,
    required this.status,
  });

  static VerifiedRepository fromJson(Map<String, dynamic> json) =>
      _$VerifiedRepositoryFromJson(json);

  Map<String, dynamic> toJson() => _$VerifiedRepositoryToJson(this);
}

enum RepositoryVerificationStatus {
  // Eg. failed to clone the repository.
  verificationUnknown,
  // The repository did not contain the correct pubspec.yaml.
  repositoryLinkInvalid,
  // The repository contains the correct pubspec.yaml.
  repositoryLinkValid,
}
