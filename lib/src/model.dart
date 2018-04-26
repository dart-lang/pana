// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:math' as math;

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:quiver/core.dart' show hashObjects;

import 'platform.dart';
import 'pubspec.dart';
import 'utils.dart' show toRelativePath;

part 'model.g.dart';

@JsonSerializable()
class Summary extends Object with _$SummarySerializerMixin {
  @JsonKey(nullable: false)
  final PanaRuntimeInfo runtimeInfo;

  final String packageName;

  @JsonKey(includeIfNull: false)
  final Version packageVersion;

  final Pubspec pubspec;

  final DartPlatform platform;
  final List<LicenseFile> licenses;

  @JsonKey(includeIfNull: false)
  final Maintenance maintenance;

  final Fitness fitness;

  @JsonKey(includeIfNull: false)
  final List<Suggestion> suggestions;

  final PkgResolution pkgResolution;
  final Map<String, DartFileSummary> dartFiles;

  Summary(
    this.runtimeInfo,
    this.packageName,
    this.packageVersion,
    this.pubspec,
    this.pkgResolution,
    this.dartFiles,
    this.platform,
    this.licenses,
    this.fitness,
    this.maintenance,
    this.suggestions,
  );

  factory Summary.fromJson(Map<String, dynamic> json) =>
      _$SummaryFromJson(json);

  Iterable<CodeProblem> get codeProblems => dartFiles.values
      .map((dfs) => dfs.codeProblems)
      .where((l) => l != null)
      .expand((list) => list);
}

@JsonSerializable()
class PanaRuntimeInfo extends Object with _$PanaRuntimeInfoSerializerMixin {
  final String panaVersion;
  final String sdkVersion;
  @JsonKey(includeIfNull: false)
  final Map<String, dynamic> flutterVersions;

  PanaRuntimeInfo({
    this.panaVersion,
    this.sdkVersion,
    this.flutterVersions,
  });

  factory PanaRuntimeInfo.fromJson(Map<String, dynamic> json) =>
      _$PanaRuntimeInfoFromJson(json);
}

@JsonSerializable()
class DartFileSummary extends Object with _$DartFileSummarySerializerMixin {
  final String uri;
  final int size;

  /// If this file is formatted with `dartfmt`.
  ///
  /// `true` if it is.
  /// `false` if it is not.
  /// `null` if `dartfmt` failed while running.
  final bool isFormatted;
  final List<CodeProblem> codeProblems;

  @JsonKey(includeIfNull: false)
  final List<String> directLibs;
  @JsonKey(includeIfNull: false)
  final List<String> transitiveLibs;
  @JsonKey(includeIfNull: false)
  final DartPlatform platform;
  @JsonKey(includeIfNull: false)
  final Fitness fitness;

  DartFileSummary(
    this.uri,
    this.size,
    this.isFormatted,
    this.codeProblems,
    this.directLibs,
    this.transitiveLibs,
    this.platform,
    this.fitness,
  );

  factory DartFileSummary.fromJson(Map<String, dynamic> json) =>
      _$DartFileSummaryFromJson(json);

  /// The relative path in the package archive.
  String get path => toRelativePath(uri);
  bool get isInBin => path.startsWith('bin/');
  bool get isInLib => path.startsWith('lib/');
  bool get isInLibSrc => path.startsWith('lib/src/');

  /// Whether the file provides a public API for the package users.
  bool get isPublicApi => isInLib && !isInLibSrc;

  /// Whether the file has any local import that point outside of the lib/
  bool get hasOutsideLibDependency =>
      directLibs != null &&
      directLibs.any((String lib) => lib.startsWith('asset:'));

  bool get hasCodeError =>
      (codeProblems?.any((cp) => cp.isError) ?? false) ||
      hasOutsideLibDependency;

  CodeProblem get firstCodeError =>
      codeProblems?.firstWhere((cp) => cp.isError, orElse: () => null);
}

@JsonSerializable()
class Suggestion extends Object
    with _$SuggestionSerializerMixin
    implements Comparable<Suggestion> {
  final String level;
  final String title;
  final String description;

  @JsonKey(includeIfNull: false)
  final String file;

  @JsonKey(includeIfNull: false)
  final Penalty penalty;

  Suggestion(
    this.level,
    this.title,
    this.description, {
    this.file,
    this.penalty,
  });

  factory Suggestion.bug(String message, Object error, StackTrace stack) {
    final title =
        'There is likely a bug in the analysis code or a dependency: $message';
    final description =
        LineSplitter.split([error, '', stack].join('\n')).take(100).join('\n');
    return new Suggestion(SuggestionLevel.bug, title, description);
  }

  factory Suggestion.error(String title, String description,
          {String file, Penalty penalty}) =>
      new Suggestion(SuggestionLevel.error, title, description,
          file: file, penalty: penalty);

  factory Suggestion.warning(String title, String description,
          {String file, Penalty penalty}) =>
      new Suggestion(SuggestionLevel.warning, title, description,
          file: file, penalty: penalty);

  factory Suggestion.hint(String title, String description,
          {String file, Penalty penalty}) =>
      new Suggestion(SuggestionLevel.hint, title, description,
          file: file, penalty: penalty);

  factory Suggestion.fromJson(Map<String, dynamic> json) =>
      _$SuggestionFromJson(json);

  /// An issue that prevents platform classification.
  bool get isError =>
      level == SuggestionLevel.error || level == SuggestionLevel.bug;

  /// An issue that would improve the package quality if fixed.
  bool get isWarning => level == SuggestionLevel.warning;

  /// An issue that would be nice if it were fixed.
  bool get isHint => level == SuggestionLevel.hint;

  @override
  int compareTo(Suggestion other) {
    if (isError && !other.isError) return -1;
    if (other.isError && !isError) return 1;
    if (isWarning && !other.isError && !other.isWarning) return -1;
    if (other.isWarning && !isError && !isWarning) return 1;
    if (penalty != null && other.penalty == null) return -1;
    if (penalty == null && other.penalty != null) return 1;
    if (penalty != null && other.penalty != null) {
      final compared = -penalty.compareTo(other.penalty);
      if (compared != 0) return compared;
    }
    if (file != null && other.file != null && file != other.file) {
      return file.compareTo(other.file);
    }
    return 0;
  }

  String toString() => 'Sugestion: $level - $description';
}

abstract class SuggestionLevel {
  static const String error = 'error';
  static const String warning = 'warning';
  static const String hint = 'hint';
  static const String bug = 'bug';
}

/// Penalty values are set as integers, and shall be divided by 10000 for any
/// numerical calculation (similar to basis points in finance).
///
/// When multiple operations are present, the larger penalty is applied.
@JsonSerializable()
class Penalty extends Object
    with _$PenaltySerializerMixin
    implements Comparable<Penalty> {
  /// The value to subtract from the original score.
  /// E.g. if [amount] is 123, this is `x = x - 0.0123;`
  @JsonKey(includeIfNull: false)
  final int amount;

  /// The fraction to substract from the original score.
  /// E.g. if [fraction is 123, this is `x = x * (1.0 - 0.0123);`
  @JsonKey(includeIfNull: false)
  final int fraction;

  Penalty({
    this.amount: 0,
    this.fraction: 0,
  }) {
    assert(amount > 0 || fraction > 0);
    assert(0 <= amount && amount <= 10000);
    assert(0 <= fraction && fraction <= 10000);
  }

  factory Penalty.fromJson(Map<String, dynamic> json) =>
      _$PenaltyFromJson(json);

  double apply(double score) {
    final d1 = amount / 10000;
    final d2 = score * fraction / 10000;
    final s = score - math.max(d1, d2);
    return math.max(0.0, s);
  }

  @override
  int compareTo(Penalty other) {
    final fractionDir = fraction.compareTo(other.fraction);
    if (fractionDir == 0) {
      return amount.compareTo(other.amount);
    } else {
      return fractionDir;
    }
  }
}

abstract class PlatformNames {
  /// Package uses or depends on Flutter.
  static const String flutter = 'flutter';

  /// Package is available in web applications.
  static const String web = 'web';

  /// Package is available in web applications.
  static const String other = 'other';
}

abstract class ComponentNames {
  /// Flutter and related libraries
  static const String flutter = 'flutter';

  /// dart:html and related libraries
  static const String html = 'html';

  /// dart:js and related libraries
  static const String js = 'js';

  /// dart:io and related libraries
  static const String io = 'io';

  /// dart:isolate and related libraries
  static const String isolate = 'isolate';

  /// dart:nativewrappers and related libraries
  static const String nativewrappers = 'nativewrappers';

  /// Transformers and other build tools.
  static const String build = 'build';

  /// dart:mirrors and related libraries
  static const String mirrors = 'mirrors';
}

enum PlatformUse {
  /// is allowed, but not used
  allowed,

  /// is allowed AND used
  used,

  /// is forbidden AND used
  conflict,

  /// is forbidden, but not used
  forbidden,
}

bool _isAllowed(PlatformUse value) =>
    value == PlatformUse.allowed || value == PlatformUse.used;

@JsonSerializable()
class DartPlatform extends Object with _$DartPlatformSerializerMixin {
  @JsonKey(includeIfNull: false)
  final List<String> components;

  @JsonKey(includeIfNull: false)
  final Map<String, PlatformUse> uses;

  @JsonKey(includeIfNull: false)
  final String reason;

  DartPlatform(this.components, this.uses, {this.reason});

  factory DartPlatform.conflict(String reason) =>
      new DartPlatform(null, null, reason: reason);

  factory DartPlatform.fromComponents(List<String> components,
      {String reason}) {
    final defs = components
        .map((c) => ComponentDef.values.singleWhere((def) => def.name == c))
        .toList();
    return new DartPlatform(components, PlatformDef.detectUses(defs),
        reason: reason);
  }

  factory DartPlatform.everywhere(String reason) =>
      new DartPlatform.fromComponents([], reason: reason);

  factory DartPlatform.fromJson(Map<String, dynamic> json) =>
      _$DartPlatformFromJson(json);

  bool get worksEverywhere =>
      uses != null && uses.values.every((s) => _isAllowed(s));
  bool get worksAnywhere =>
      uses != null && uses.values.any((s) => _isAllowed(s));
  bool get hasConflict => !worksAnywhere;

  bool get worksOnFlutter => _worksOn(PlatformNames.flutter);
  bool get worksOnWeb => _worksOn(PlatformNames.web);
  bool get worksOnOther => _worksOn(PlatformNames.other);

  bool get usesFlutter => _uses(PlatformNames.flutter);

  /// Visible for testing only, DO NOT USE in clients.
  String get longPlatformDebug => uses.keys
      .map((k) => '$k: ${uses[k].toString().split('.').last}')
      .join(', ');

  bool _worksOn(String name) => uses != null && _isAllowed(uses[name]);

  bool _uses(String name) => uses != null && uses[name] == PlatformUse.used;
}

@JsonSerializable()
class PkgResolution extends Object with _$PkgResolutionSerializerMixin {
  final List<PkgDependency> dependencies;

  PkgResolution(this.dependencies);

  factory PkgResolution.fromJson(Map<String, dynamic> json) =>
      _$PkgResolutionFromJson(json);

  List<PkgDependency> get outdated =>
      dependencies.where((pd) => pd.isOutdated).toList();

  Map<String, int> getStats(Pubspec pubspec) {
    // counts: direct, dev, transitive
    // outdated count, by constraint: direct, dev
    // outdated count, other: all
    var directDeps = pubspec.dependencies?.length ?? 0;
    var devDeps = pubspec.devDependencies?.length ?? 0;

    var transitiveDeps = dependencies.where((pd) => pd.isTransitive).length;

    var data = <String, int>{
      'deps_direct': directDeps,
      'deps_dev': devDeps,
      'deps_transitive': transitiveDeps,
      'outdated_direct': outdated.where((pvd) => pvd.isDirect).length,
      'outdated_dev': outdated.where((pvd) => pvd.isDev).length,
      'outdated_transitive': outdated.where((pvd) => pvd.isTransitive).length,
    };

    return data;
  }

  List<PkgDependency> getUnconstrainedDeps(
      {bool onlyDirect: false, bool includeSdk: false}) {
    return dependencies
        .where((pd) => !onlyDirect || pd.isDirect)
        .where((pd) => includeSdk || pd.constraintType != ConstraintTypes.sdk)
        .where((pd) =>
            pd.constraint == null ||
            pd.constraint.isAny ||
            (pd.constraint is VersionRange &&
                (pd.constraint as VersionRange).max == null))
        .toList();
  }
}

enum VersionResolutionType {
  /// The resolved version is the latest.
  latest,

  /// The latest version is not available due to a version constraint.
  constrained,

  /// Other, unknown?
  other,
}

abstract class DependencyTypes {
  static final String direct = 'direct';
  static final String dev = 'dev';
  static final String transitive = 'transitive';
}

abstract class ConstraintTypes {
  static final String empty = 'empty';
  static final String normal = 'normal';
  static final String sdk = 'sdk';
  static final String git = 'git';
  static final String path = 'path';
  static final String inherited = 'inherited';
  static final String unknown = 'unknown';
}

@JsonSerializable()
class PkgDependency extends Object
    with _$PkgDependencySerializerMixin
    implements Comparable<PkgDependency> {
  final String package;

  final String dependencyType;

  final String constraintType;

  @JsonKey(includeIfNull: false)
  final VersionConstraint constraint;

  @JsonKey(includeIfNull: false)
  final Version resolved;

  @JsonKey(includeIfNull: false)
  final Version available;

  @JsonKey(includeIfNull: false)
  final List<String> errors;

  PkgDependency(this.package, this.dependencyType, this.constraintType,
      this.constraint, this.resolved, this.available, this.errors);

  factory PkgDependency.fromJson(Map<String, dynamic> json) =>
      _$PkgDependencyFromJson(json);

  bool get isDirect => dependencyType == DependencyTypes.direct;
  bool get isDev => dependencyType == DependencyTypes.dev;
  bool get isTransitive => dependencyType == DependencyTypes.transitive;

  bool get isLatest => available == null;
  bool get isOutdated => !isLatest;

  bool get isHosted =>
      constraintType != ConstraintTypes.sdk &&
      constraintType != ConstraintTypes.path &&
      constraintType != ConstraintTypes.git &&
      constraintType != ConstraintTypes.unknown;

  VersionResolutionType get resolutionType {
    if (isLatest) return VersionResolutionType.latest;

    if (constraint != null && constraint.allows(available)) {
      return VersionResolutionType.constrained;
    }

    if (available.isPreRelease) {
      // If the pre-release isn't allowed by the constraint, then ignore it
      // ... call it a match
      return VersionResolutionType.latest;
    }

    return VersionResolutionType.other;
  }

  @override
  int compareTo(PkgDependency other) => package.compareTo(other.package);

  @override
  String toString() {
    var items = <Object>[package];
    if (isDev) {
      items.add('(dev)');
    } else if (isTransitive) {
      items.add('(transitive)');
    }
    items.add('@$resolved');

    items.add(resolutionType.toString().split('.').last);

    if (resolutionType != VersionResolutionType.latest) {
      items.add(available);
    }
    return items.join(' ');
  }
}

/// Describes the maintenance status of the package.
@JsonSerializable()
class Maintenance extends Object with _$MaintenanceSerializerMixin {
  /// whether the package has no or too small changelog
  final bool missingChangelog;

  /// whether the package has no example
  final bool missingExample;

  /// whether the package has no or too small readme
  final bool missingReadme;

  /// whether the package has no analysis_options.yaml file
  final bool missingAnalysisOptions;

  /// whether the package has only an old .analysis-options file
  final bool oldAnalysisOptions;

  /// whether the analysis_options.yaml file has strong mode enabled
  final bool strongModeEnabled;

  /// whether version is `0.*`
  final bool isExperimentalVersion;

  /// whether version is flagged `-beta`, `-alpha`, etc.
  final bool isPreReleaseVersion;

  /// the number of errors encountered during analysis
  final int errorCount;

  /// the number of warning encountered during analysis
  final int warningCount;

  /// the number of hints encountered during analysis
  final int hintCount;

  /// The suggestions that affect the maintenance score.
  @JsonKey(includeIfNull: false)
  final List<Suggestion> suggestions;

  Maintenance({
    @required this.missingChangelog,
    @required this.missingExample,
    @required this.missingReadme,
    @required this.missingAnalysisOptions,
    @required this.oldAnalysisOptions,
    @required this.strongModeEnabled,
    @required this.isExperimentalVersion,
    @required this.isPreReleaseVersion,
    @required this.errorCount,
    @required this.warningCount,
    @required this.hintCount,
    this.suggestions,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceFromJson(json);
}

/// Describes a health metric that takes size and complexity into account.
@JsonSerializable()
class Fitness extends Object with _$FitnessSerializerMixin {
  /// Represents the size and complexity of the library.
  final double magnitude;

  /// The faults, penalties and failures to meet the standards.
  final double shortcoming;

  @JsonKey(includeIfNull: false)
  final List<Suggestion> suggestions;

  Fitness(this.magnitude, this.shortcoming, {this.suggestions});

  factory Fitness.fromJson(Map json) => _$FitnessFromJson(json);

  String toSimpleText() =>
      '${(magnitude - shortcoming).toStringAsFixed(2)} out of ${magnitude.toStringAsFixed(2)}';

  double get healthScore {
    final score = (magnitude - shortcoming) / magnitude;
    return math.max(0.0, math.min(1.0, score));
  }

  bool get hasSuggestion => suggestions != null && suggestions.isNotEmpty;
}

@JsonSerializable()
class LicenseFile extends Object with _$LicenseFileSerializerMixin {
  final String path;
  final String name;

  @JsonKey(includeIfNull: false)
  final String version;

  @JsonKey(includeIfNull: false)
  final String url;

  LicenseFile(this.path, this.name, {this.version, this.url});

  factory LicenseFile.fromJson(Map<String, dynamic> json) =>
      _$LicenseFileFromJson(json);

  LicenseFile change({String url}) =>
      new LicenseFile(path, name, version: version, url: url ?? this.url);

  String get shortFormatted => version == null ? name : '$name $version';

  @override
  String toString() => '$path: $shortFormatted';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseFile &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          name == other.name &&
          version == other.version &&
          url == other.url;

  @override
  int get hashCode =>
      path.hashCode ^ name.hashCode ^ version.hashCode ^ url.hashCode;
}

abstract class LicenseNames {
  static const String AGPL = 'AGPL';
  static const String Apache = 'Apache';
  static const String BSD = 'BSD';
  static const String GPL = 'GPL';
  static const String LGPL = 'LGPL';
  static const String MIT = 'MIT';
  static const String MPL = 'MPL';
  static const String Unlicense = 'Unlicense';
  static const String unknown = 'unknown';
}

@JsonSerializable()
class CodeProblem extends Object
    with _$CodeProblemSerializerMixin
    implements Comparable<CodeProblem> {
  /// The errors which don't block platform classification.
  static const _platformNonBlockerTypes = const <String>[
    'STATIC_TYPE_WARNING',
    'STATIC_WARNING',
  ];

  static const _platformNonBlockerCodes = const <String>[
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
  final String description;

  CodeProblem(this.severity, this.errorType, this.errorCode, this.description,
      this.file, this.line, this.col);

  factory CodeProblem.fromJson(Map<String, dynamic> json) =>
      _$CodeProblemFromJson(json);

  bool get isError => severity?.toUpperCase() == 'ERROR';
  bool get isWarning => severity?.toUpperCase() == 'WARNING';
  bool get isInfo => severity?.toUpperCase() == 'INFO';

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

  @override
  int get hashCode => hashObjects(_values);

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
