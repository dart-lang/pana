// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

import 'json_converters.dart';
import 'pubspec.dart';
import 'repository/repository_url_parser.dart';

export 'repository/repository_url_resolver.dart';

part 'model.g.dart';

/// A processed screenshot contains paths with processed images as stored using
///  `storeResource` as passed to `PackageAnalyzer.inspectPackage`.
@JsonSerializable()
class ProcessedScreenshot {
  final String originalImage; // <imagePath>
  final String webpImage; // gen/<imagePath>.webp
  final String webp100Thumbnail; // gen/100x100/<imagePath>.webp
  final String png100Thumbnail; // gen/100x100/<imagePath>.png
  final String webp190Thumbnail; // gen/190x190/<imagePath>.webp
  final String png190Thumbnail; // gen/190x190/<imagePath>.png
  final String description;

  ProcessedScreenshot(
    this.originalImage,
    this.description, {
    required this.webpImage,
    required this.webp100Thumbnail,
    required this.png100Thumbnail,
    required this.webp190Thumbnail,
    required this.png190Thumbnail,
  });

  factory ProcessedScreenshot.fromJson(Map<String, dynamic> json) =>
      _$ProcessedScreenshotFromJson(json);

  Map<String, dynamic> toJson() => _$ProcessedScreenshotToJson(this);
}

@JsonSerializable()
@VersionConverter()
class Summary {
  final DateTime? createdAt;
  final PanaRuntimeInfo runtimeInfo;
  final String? packageName;
  final Version? packageVersion;
  final Pubspec? pubspec;

  /// The packages that are either direct-, dev- or transient dependencies.
  final List<String>? allDependencies;
  final List<String>? tags;
  final Report? report;
  final List<ProcessedScreenshot>? screenshots;
  final AnalysisResult? result;

  /// URLs that are invalid, unsafe or missing.
  final List<UrlProblem>? urlProblems;

  /// Markdown-formatted text with errors encountered by `pana`.
  final String? errorMessage;

  Summary({
    required this.createdAt,
    required this.runtimeInfo,
    this.packageName,
    this.packageVersion,
    this.pubspec,
    this.allDependencies,
    this.tags,
    this.report,
    this.result,
    this.urlProblems,
    this.errorMessage,
    this.screenshots,
  });

  factory Summary.fromJson(Map<String, dynamic> json) =>
      _$SummaryFromJson(json);

  Map<String, dynamic> toJson() => _$SummaryToJson(this);

  Summary change({
    DateTime? createdAt,
    PanaRuntimeInfo? runtimeInfo,
    List<String>? tags,
    Report? report,
    AnalysisResult? result,
  }) {
    return Summary(
      createdAt: createdAt ?? this.createdAt,
      runtimeInfo: runtimeInfo ?? this.runtimeInfo,
      packageName: packageName,
      packageVersion: packageVersion,
      pubspec: pubspec,
      allDependencies: allDependencies,
      tags: tags ?? this.tags,
      report: report ?? this.report,
      result: result ?? this.result,
      urlProblems: urlProblems,
      errorMessage: errorMessage,
      screenshots: screenshots,
    );
  }
}

@JsonSerializable()
class PanaRuntimeInfo {
  final String panaVersion;
  final String sdkVersion;
  final Map<String, dynamic>? flutterVersions;

  PanaRuntimeInfo({
    required this.panaVersion,
    required this.sdkVersion,
    this.flutterVersions,
  });

  factory PanaRuntimeInfo.fromJson(Map<String, dynamic> json) =>
      _$PanaRuntimeInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PanaRuntimeInfoToJson(this);

  bool get hasFlutter => flutterVersions?.isNotEmpty ?? false;

  /// The Flutter SDK version.
  String? get flutterVersion => flutterVersions?['frameworkVersion'] as String?;

  /// The Dart SDK used by Flutter internally.
  String? get flutterInternalDartSdkVersion {
    final value = flutterVersions?['dartSdkVersion'] as String?;
    if (value == null) return null;
    final parts = value.split(' ');
    if (parts.length > 2 && parts[1] == '(build' && parts[2].endsWith(')')) {
      final buildValue = parts[2].split(')').first;
      try {
        Version.parse(buildValue);
        return buildValue;
      } catch (_) {
        // ignore
      }
    }
    return parts.first;
  }
}

/// Describes the details of the license detection results.
/// NOTE: the content of the class is experimental, clients should not rely on it yet.
@JsonSerializable()
class License {
  /// The SPDX identifier of the license.
  final String spdxIdentifier;

  /// The range (start and end position) of the recognized part.
  ///
  /// WARNING: this field is experimental, do not rely on it.
  final Range? range;

  License({required this.spdxIdentifier, this.range});

  factory License.fromJson(Map<String, dynamic> json) =>
      _$LicenseFromJson(json);

  Map<String, dynamic> toJson() => _$LicenseToJson(this);
}

/// Describes a range in a source file.
///
/// WARNING: this class is experimental, do not rely on it.
@JsonSerializable()
class Range {
  final Position start;
  final Position end;

  /// Pair of values that indicate start-end offsets that inside the range are
  /// covering the license text.
  final List<int> coverages;

  Range({required this.start, required this.end, required this.coverages});

  factory Range.fromJson(Map<String, dynamic> json) => _$RangeFromJson(json);

  Map<String, dynamic> toJson() => _$RangeToJson(this);
}

/// Describes a position in a source file.
///
/// WARNING: this class is experimental, do not rely on it.
@JsonSerializable()
class Position {
  /// The 0-based offset in the source.
  final int offset;

  /// The 0-based line in the source.
  final int line;

  /// The 0-based column in the source
  final int column;

  Position({required this.offset, required this.line, required this.column});

  factory Position.fromJson(Map<String, dynamic> json) =>
      _$PositionFromJson(json);

  Map<String, dynamic> toJson() => _$PositionToJson(this);
}

/// Models the 'new-style' pana report.
@JsonSerializable()
class Report {
  /// The scoring sections.
  final List<ReportSection> sections;

  Report({required this.sections});

  static Report fromJson(Map<String, dynamic> json) => _$ReportFromJson(json);

  Map<String, dynamic> toJson() => _$ReportToJson(this);

  int get grantedPoints =>
      sections.fold<int>(0, (sum, section) => sum + section.grantedPoints);

  int get maxPoints =>
      sections.fold<int>(0, (sum, section) => sum + section.maxPoints);
}

abstract class ReportSectionId {
  static const analysis = 'analysis';
  static const convention = 'convention';
  static const dependency = 'dependency';
  static const documentation = 'documentation';
  static const platform = 'platform';
}

enum ReportStatus {
  @JsonValue('failed')
  failed,
  @JsonValue('partial')
  partial,
  @JsonValue('passed')
  passed,
}

@JsonSerializable()
class ReportSection {
  final String id;
  final String title;

  /// How many points did this section score
  final int grantedPoints;

  /// How many points could this section have scored.
  final int maxPoints;

  /// Is this section considered passing.
  final ReportStatus status;

  /// Should describe the overall goals in a few lines, followed by
  /// descriptions of each issue that resulted in [grantedPoints] being less
  /// than  [maxPoints] (if any).
  ///
  /// Markdown formatted.
  final String summary;

  ReportSection({
    required this.id,
    required this.title,
    required this.grantedPoints,
    required this.maxPoints,
    required this.summary,
    required this.status,
  });

  static ReportSection fromJson(Map<String, dynamic> json) =>
      _$ReportSectionFromJson(json);

  Map<String, dynamic> toJson() => _$ReportSectionToJson(this);
}

/// NOTE: the content of the class is experimental, clients should not rely on it yet.
/// The normalized and verified references and derived values of the analysis.
///
/// When a value is present, it has been tried and verified to be working.
///
/// When a value is absent, it was either absent in package archive, or the
/// verification of the provided value failed. In the failure cases, the
/// findings of the process are presented in the [Report].
@JsonSerializable()
class AnalysisResult {
  final String? homepageUrl;
  final String? repositoryUrl;
  final String? issueTrackerUrl;
  final String? documentationUrl;
  final List<String>? fundingUrls;
  final RepositoryStatus? repositoryStatus;
  final Repository? repository;
  final String? contributingUrl;
  final List<License>? licenses;
  final int? grantedPoints;
  final int? maxPoints;

  AnalysisResult({
    this.homepageUrl,
    this.repositoryUrl,
    this.issueTrackerUrl,
    this.documentationUrl,
    this.fundingUrls,
    this.repositoryStatus,
    this.repository,
    this.contributingUrl,
    this.licenses,
    this.grantedPoints,
    this.maxPoints,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$AnalysisResultFromJson(json);

  Map<String, dynamic> toJson() => _$AnalysisResultToJson(this);
}

/// The status of the repository verification.
enum RepositoryStatus {
  /// The repository URL was not specified, empty, or we were not able to
  /// infer it (e.g. from `homepage`).
  ///
  /// No verification was done.
  unspecified,

  /// The specified URL was not a valid or secure URL.
  ///
  /// No verification was done.
  invalid,

  /// There was no repository found on the specified URL.
  /// The issue may be transient, a repeated access may find it.
  ///
  /// No verification was done.
  missing,

  /// The repository did not pass verification tests.
  failed,

  /// The repository passed verification tests.
  verified,

  /// The repository verification encountered a failure, result is
  /// not conclusive.
  inconclusive,
}

/// NOTE: the content of the class is experimental, clients should not rely on it yet.
/// To get successful verification, the remote repository:
///   - must be a valid remote repository with public access,
///   - must contain a `pubspec.yaml` in the location specified by the repository URL,
///   - must have the same package name and repository URL in the `pubspec.yaml` that
///     was used to analyze the package,
///   - must have a valid version,
///   - must not have a `publish_to` key.
@JsonSerializable()
class Repository {
  /// The type of the software hosting the repository.
  ///
  /// Influences URL resolution methods - known providers will have better relative links.
  final RepositoryProvider provider;

  /// The host (domain name) of the repository.
  final String host;

  /// The relative path to the entry point of the repository.
  ///
  /// e.g. `<user-or-org>/<project>` on GitHub
  final String? repository;

  /// The name of the default branch.
  final String? branch;

  /// The local path in the repository to the package directory.
  final String? path;

  Repository({
    required RepositoryProvider? provider,
    required this.host,
    required this.repository,
    required this.branch,
    required this.path,
  }) : provider = provider ?? RepositoryProvider.unknown;

  factory Repository.fromJson(Map<String, dynamic> json) =>
      _$RepositoryFromJson(json);

  /// Parses [input] and return the parsed [Repository] if successful,
  /// or returns `null` if it was unable to recognize the pattern.
  static Repository? tryParseUrl(String input) => tryParseRepositoryUrl(input);

  /// Parses [input] and return the parsed [Repository] if successful,
  /// or throws [FormatException] if it was unable to recognize the pattern.
  factory Repository.parseUrl(String input) {
    try {
      return parseRepositoryUrl(input);
    } on FormatException catch (e) {
      throw FormatException('Invalid repository URL: ${e.message}');
    }
  }

  Map<String, dynamic> toJson() => _$RepositoryToJson(this);
}

/// The identifier of repository provider, which could influence how relative URLs are resolved.
enum RepositoryProvider {
  /// GitHub
  github,

  /// GitLab (cloud or self-hosted)
  gitlab,

  /// Unable to identify.
  unknown;

  /// Whether the provider follows the GitHub URL conventions.
  static bool isGitHubCompatible(RepositoryProvider? provider) =>
      provider == github || provider == gitlab;
}

@JsonSerializable()
class UrlProblem {
  final String url;

  /// One of [UrlProblemCodes].
  final String problem;

  UrlProblem({required this.url, required this.problem});

  factory UrlProblem.fromJson(Map<String, dynamic> json) =>
      _$UrlProblemFromJson(json);

  Map<String, dynamic> toJson() => _$UrlProblemToJson(this);
}

/// Possible values for [UrlProblem.problem].
abstract class UrlProblemCodes {
  static const invalid = 'invalid';
  static const insecure = 'insecure';
  static const missing = 'missing';
}
