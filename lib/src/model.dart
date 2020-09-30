// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:quiver/core.dart' show hashObjects;

import 'json_converters.dart';
import 'pubspec.dart';

part 'model.g.dart';

@JsonSerializable()
@VersionConverter()
class Summary {
  @JsonKey(nullable: false)
  final PanaRuntimeInfo runtimeInfo;

  final String packageName;

  @JsonKey(includeIfNull: false)
  final Version packageVersion;

  @JsonKey(includeIfNull: false)
  final Pubspec pubspec;

  final LicenseFile licenseFile;

  @JsonKey(includeIfNull: false)
  final PkgResolution pkgResolution;

  @JsonKey(includeIfNull: false)
  final List<String> tags;

  @JsonKey(includeIfNull: false)
  final Report report;

  /// Markdown-formatted text with errors encountered by `pana`.
  @JsonKey(includeIfNull: false)
  final String errorMessage;

  Summary({
    @required this.runtimeInfo,
    @required this.packageName,
    @required this.packageVersion,
    @required this.pubspec,
    @required this.pkgResolution,
    @required this.licenseFile,
    @required this.tags,
    @required this.report,
    @required this.errorMessage,
  });

  factory Summary.fromJson(Map<String, dynamic> json) =>
      _$SummaryFromJson(json);

  Map<String, dynamic> toJson() => _$SummaryToJson(this);

  Summary change({
    PanaRuntimeInfo runtimeInfo,
    List<String> tags,
  }) {
    return Summary(
      runtimeInfo: runtimeInfo ?? this.runtimeInfo,
      packageName: packageName,
      packageVersion: packageVersion,
      pubspec: pubspec,
      pkgResolution: pkgResolution,
      licenseFile: licenseFile,
      tags: tags ?? this.tags,
      report: report,
      errorMessage: errorMessage,
    );
  }
}

@JsonSerializable()
class PanaRuntimeInfo {
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

  Map<String, dynamic> toJson() => _$PanaRuntimeInfoToJson(this);
}

@JsonSerializable()
class PkgResolution {
  final List<PkgDependency> dependencies;

  PkgResolution(this.dependencies);

  factory PkgResolution.fromJson(Map<String, dynamic> json) =>
      _$PkgResolutionFromJson(json);

  Map<String, dynamic> toJson() => _$PkgResolutionToJson(this);

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
      {bool onlyDirect = false, bool includeSdk = false}) {
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
@VersionConverter()
@VersionConstraintConverter()
class PkgDependency implements Comparable<PkgDependency> {
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

  PkgDependency({
    @required this.package,
    @required this.dependencyType,
    @required this.constraintType,
    @required this.constraint,
    @required this.resolved,
    @required this.available,
    @required this.errors,
  });

  factory PkgDependency.fromJson(Map<String, dynamic> json) =>
      _$PkgDependencyFromJson(json);

  Map<String, dynamic> toJson() => _$PkgDependencyToJson(this);

  bool get isDirect => dependencyType == DependencyTypes.direct;

  bool get isDev => dependencyType == DependencyTypes.dev;

  bool get isTransitive => dependencyType == DependencyTypes.transitive;

  bool get isLatest => available == null;

  // TODO: investigate if `pub upgrade` reports the latest stable or the latest uploaded
  bool get isOutdated => available != null && !available.isPreRelease;

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

@JsonSerializable()
class LicenseFile {
  final String path;
  final String name;

  @JsonKey(includeIfNull: false)
  final String version;

  @JsonKey(includeIfNull: false)
  final String url;

  LicenseFile(this.path, this.name, {this.version, this.url});

  factory LicenseFile.fromJson(Map<String, dynamic> json) =>
      _$LicenseFileFromJson(json);

  Map<String, dynamic> toJson() => _$LicenseFileToJson(this);

  LicenseFile change({String url}) =>
      LicenseFile(path, name, version: version, url: url ?? this.url);

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
    @required this.severity,
    @required this.errorType,
    @required this.errorCode,
    @required this.description,
    @required this.file,
    @required this.line,
    @required this.col,
    @required this.length,
  });

  factory CodeProblem.fromJson(Map<String, dynamic> json) =>
      _$CodeProblemFromJson(json);

  Map<String, dynamic> toJson() => _$CodeProblemToJson(this);

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

/// Models the 'new-style' pana report.
@JsonSerializable(explicitToJson: true)
class Report {
  /// The scoring sections.
  final List<ReportSection> sections;

  Report({@required this.sections});

  static Report fromJson(Map<String, dynamic> json) => _$ReportFromJson(json);
  Map<String, dynamic> toJson() => _$ReportToJson(this);

  int get grantedPoints =>
      sections.fold<int>(0, (sum, section) => sum + section.grantedPoints);

  int get maxPoints =>
      sections.fold<int>(0, (sum, section) => sum + section.maxPoints);

  /// Creates a new [Report] instance with [section] extending and already
  /// existing [ReportSection]. The sections are matched via the `title`.
  ///
  /// The granted and max points will be added to the existing section.
  /// The summary will be appended to the end of the existing summary.
  ///
  /// If there is no section matched, the section will be added to the end of
  /// the sections list.
  Report joinSection(ReportSection section) {
    final matched = sections.firstWhere(
        (s) => (s.id != null && s.id == section.id) || s.title == section.title,
        orElse: () => null);
    if (matched == null) {
      return Report(sections: [...sections, section]);
    } else {
      return Report(
          sections: sections.map(
        (s) {
          if (s != matched) {
            return s;
          }
          return ReportSection(
            id: s.id,
            title: s.title,
            maxPoints: s.maxPoints + section.maxPoints,
            grantedPoints: s.grantedPoints + section.grantedPoints,
            summary: [s.summary.trim(), section.summary.trim()].join('\n\n'),
          );
        },
      ).toList());
    }
  }
}

abstract class ReportSectionId {
  static const analysis = 'analysis';
  static const convention = 'convention';
  static const dependency = 'dependency';
  static const documentation = 'documentation';
  static const platform = 'platform';
}

@JsonSerializable()
class ReportSection {
  final String id;
  final String title;

  /// How many points did this section score
  final int grantedPoints;

  /// How many points could this section have scored.
  final int maxPoints;

  /// Should describe the overall goals in a few lines, followed by
  /// descriptions of each issue that resulted in [grantedPoints] being less
  /// than  [maxPoints] (if any).
  ///
  /// Markdown formatted.
  final String summary;

  ReportSection({
    @required this.id,
    @required this.title,
    @required this.grantedPoints,
    @required this.maxPoints,
    @required this.summary,
  });

  static ReportSection fromJson(Map<String, dynamic> json) =>
      _$ReportSectionFromJson(json);
  Map<String, dynamic> toJson() => _$ReportSectionToJson(this);
}

/// The json output from `pub outdated --json`.
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
  final VersionDescriptor upgradable;
  final VersionDescriptor latest;

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
