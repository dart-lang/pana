import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart' as pubspek show Pubspec;
import 'package:pubspec_parse/pubspec_parse.dart' hide Pubspec;
import 'package:yaml/yaml.dart' as yaml;

import 'utils.dart';

class Pubspec {
  final pubspek.Pubspec _inner;
  final Map _content;

  Set<String> _dependentSdks;

  Pubspec(Map content)
      : _inner = pubspek.Pubspec.fromJson(content, lenient: true),
        _content = content;

  factory Pubspec.parseFromDir(String packageDir) {
    var content = getPubspecContent(packageDir);
    if (content == null) {
      throw Exception("Couldn't find a pubspec.yaml in $packageDir.");
    }
    return Pubspec.parseYaml(content);
  }

  factory Pubspec.parseYaml(String content) =>
      Pubspec(Map<String, dynamic>.from(yaml.loadYaml(content) as Map));

  factory Pubspec.fromJson(Map<String, dynamic> json) => Pubspec(json);

  Map toJson() => _content;

  String get name => _inner.name;
  String get description => _inner.description;

  Version get version => _inner.version;

  List<String> get authors => _inner.authors;

  Map<String, Dependency> get dependencies => _inner.dependencies;

  Map<String, Dependency> get devDependencies => _inner.devDependencies;

  bool dependsOnPackage(String package) =>
      (dependencies?.containsKey(package) ?? false) ||
      (devDependencies?.containsKey(package) ?? false);

  bool get hasFlutterKey => _content.containsKey('flutter');
  bool get hasFlutterPluginKey =>
      hasFlutterKey &&
      _content['flutter'] is Map &&
      _content['flutter']['plugin'] != null;

  bool get dependsOnFlutterSdk => dependentSdks.contains('flutter');
  bool get dependsOnFlutterPackage => dependsOnPackage('flutter');

  bool get usesFlutter =>
      dependsOnFlutterSdk || dependsOnFlutterPackage || hasFlutterKey;

  @deprecated
  bool get isFlutter => usesFlutter;

  Set<String> get dependentSdks {
    if (_dependentSdks == null) {
      _dependentSdks = SplayTreeSet();
      dependencies?.values?.forEach((value) {
        if (value is SdkDependency) {
          _dependentSdks.add(value.sdk);
        }
      });
      devDependencies?.values?.forEach((value) {
        if (value is SdkDependency) {
          _dependentSdks.add(value.sdk);
        }
      });
      if (_inner.environment != null) {
        final keys = _inner.environment.keys.toList();
        keys.remove('sdk');
        _dependentSdks.addAll(keys);
      }
    }
    return _dependentSdks;
  }

  Set<String> get unknownSdks {
    var unknowns = Set<String>.from(dependentSdks);
    unknowns.remove('flutter');
    return unknowns;
  }

  bool get hasUnknownSdks => unknownSdks.isNotEmpty;

  String get homepage => _inner.homepage;

  String get documentation => _inner.documentation;

  String get repository => _inner.repository?.toString();

  String get issueTracker => _inner.issueTracker?.toString();

  bool get hasDartSdkConstraint => sdkConstraintStatus.hasConstraint;

  bool get shouldWarnDart2Constraint => !sdkConstraintStatus.enablesDart2Latest;

  bool get hasGitDependency =>
      _inner.dependencies.values.any((d) => d is GitDependency);

  bool get hasUnrestrictedGitDependency => _inner.dependencies.values
      .any((d) => d is GitDependency && (d.ref == null || d.ref.length < 40));

  SdkConstraintStatus get sdkConstraintStatus =>
      SdkConstraintStatus.fromSdkVersion(_inner.environment['sdk']);

  bool get usesOldFlutterPluginFormat =>
      usesFlutter &&
      _inner.flutter['plugin'] is Map<String, Object> &&
      const {
        'androidPackage',
        'iosPrefix',
        'pluginClass',
      }.any((_inner.flutter['plugin'] as Map<String, Object>).containsKey);
}

final _range2 = VersionConstraint.parse('>=2.0.0 <3.0.0');
final _range2Latest = VersionConstraint.parse('>=2.9999.0 <3.0.0');
final _futureRange = VersionConstraint.parse('>=3.0.0');
final _firstNullSafetyVersion = Version.parse('2.10.0');

/// Detailed support coverage for the SDK constraint.
class SdkConstraintStatus {
  /// Whether it is non-empty, bounded constraint.
  final bool hasConstraint;

  /// Whether it allows anything from the ^2.9999.0 range.
  final bool enablesDart2Latest;

  /// Whether it is compatible with Dart 2 SDKs.
  final bool isDart2Compatible;

  final bool hasOptedIntoNullSafety;

  SdkConstraintStatus._({
    this.hasConstraint,
    this.enablesDart2Latest,
    this.isDart2Compatible,
    this.hasOptedIntoNullSafety,
  });

  factory SdkConstraintStatus.fromSdkVersion(VersionConstraint constraint) {
    final hasConstraint =
        constraint != null && !constraint.isAny && !constraint.isEmpty;
    final enablesDart2 = hasConstraint && constraint.allowsAny(_range2);
    final enablesFutureVersions =
        hasConstraint && constraint.allowsAny(_futureRange);
    final hasOptedIntoNullSafety = hasConstraint &&
        constraint is VersionRange &&
        constraint.min != null &&
        constraint.min >= _firstNullSafetyVersion;
    return SdkConstraintStatus._(
      hasConstraint: hasConstraint,
      enablesDart2Latest: hasConstraint && constraint.allowsAny(_range2Latest),
      isDart2Compatible:
          hasConstraint && enablesDart2 && !enablesFutureVersions,
      hasOptedIntoNullSafety: hasOptedIntoNullSafety,
    );
  }
}
