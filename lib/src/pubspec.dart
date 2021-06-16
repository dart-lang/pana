// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart' as pubspek show Pubspec;
import 'package:pubspec_parse/pubspec_parse.dart' hide Pubspec;
import 'package:yaml/yaml.dart' as yaml;

import 'null_safety.dart';

class Pubspec {
  final pubspek.Pubspec _inner;
  final Map _content;

  Set<String>? _dependentSdks;

  Pubspec(Map content)
      : _inner = pubspek.Pubspec.fromJson(content, lenient: true),
        _content = content;

  factory Pubspec.parseYaml(String content, {String? sourceUrl}) =>
      Pubspec(Map<String, dynamic>.from(yaml.loadYaml(content,
          sourceUrl: sourceUrl == null ? null : Uri.parse(sourceUrl)) as Map));

  factory Pubspec.fromJson(Map<String, dynamic> json) => Pubspec(json);

  Map toJson() => _content;

  Map get originalYaml => _content;

  String get name => _inner.name;

  String? get description => _inner.description;

  Version? get version => _inner.version;

  Map<String, Dependency> get dependencies => _inner.dependencies;

  Map<String, Dependency> get devDependencies => _inner.devDependencies;

  Map get environment => (_content['environment'] as Map?) ?? {};

  bool dependsOnPackage(String package) =>
      (dependencies.containsKey(package)) ||
      (devDependencies.containsKey(package));

  bool get hasFlutterKey => _content.containsKey('flutter');

  bool get hasFlutterPluginKey =>
      hasFlutterKey &&
      _content['flutter'] is Map &&
      _content['flutter']['plugin'] != null;

  bool get dependsOnFlutterSdk => dependentSdks.contains('flutter');

  bool get dependsOnFlutterPackage => dependsOnPackage('flutter');

  bool get usesFlutter =>
      dependsOnFlutterSdk || dependsOnFlutterPackage || hasFlutterKey;

  Set<String> get dependentSdks {
    if (_dependentSdks == null) {
      _dependentSdks = SplayTreeSet();
      for (final value in dependencies.values) {
        if (value is SdkDependency) {
          _dependentSdks!.add(value.sdk);
        }
      }
      for (final value in devDependencies.values) {
        if (value is SdkDependency) {
          _dependentSdks!.add(value.sdk);
        }
      }
      if (_inner.environment != null) {
        final keys = _inner.environment!.keys.toList();
        keys.remove('sdk');
        _dependentSdks!.addAll(keys);
      }
    }
    return _dependentSdks!;
  }

  Set<String> get unknownSdks {
    var unknowns = Set<String>.from(dependentSdks);
    unknowns.remove('flutter');
    return unknowns;
  }

  bool get hasUnknownSdks => unknownSdks.isNotEmpty;

  String? get homepage => _inner.homepage;

  String? get documentation => _inner.documentation;

  String? get repository => _inner.repository?.toString();

  String? get issueTracker => _inner.issueTracker?.toString();

  bool get hasDartSdkConstraint => sdkConstraintStatus.hasConstraint;

  bool get shouldWarnDart2Constraint => !sdkConstraintStatus.enablesDart2Latest;

  bool get hasGitDependency =>
      _inner.dependencies.values.any((d) => d is GitDependency);

  bool get hasUnrestrictedGitDependency => _inner.dependencies.values
      .any((d) => d is GitDependency && (d.ref == null || d.ref!.length < 40));

  SdkConstraintStatus get sdkConstraintStatus =>
      SdkConstraintStatus.fromSdkVersion(_inner.environment?['sdk']);

  VersionConstraint? get dartSdkConstraint => _inner.environment?['sdk'];

  VersionConstraint? get flutterSdkConstraint =>
      // Flutter constraints get special treatment, as Flutter won't be
      // using semantic versioning to mark breaking releases.
      _removeUpperBound(_inner.environment?['flutter']);

  VersionConstraint? _removeUpperBound(VersionConstraint? constraint) {
    if (constraint is VersionRange) {
      return VersionRange(
          min: constraint.min, includeMin: constraint.includeMin);
    }
    return constraint;
  }

  bool get usesOldFlutterPluginFormat =>
      hasFlutterPluginKey &&
      _inner.flutter!['plugin'] is Map<String, dynamic> &&
      const {
        'androidPackage',
        'iosPrefix',
        'pluginClass',
      }.any((_inner.flutter!['plugin'] as Map<String, dynamic>).containsKey);
}

final _range2 = VersionConstraint.parse('>=2.0.0 <3.0.0');
final _range2Latest = VersionConstraint.parse('>=2.9999.0 <3.0.0');
final _futureRange = VersionConstraint.parse('>=3.0.0');

/// Detailed support coverage for the SDK constraint.
class SdkConstraintStatus {
  /// Whether it is non-empty, bounded constraint.
  final bool hasConstraint;

  /// Whether it allows anything from the ^2.9999.0 range.
  final bool enablesDart2Latest;

  /// Whether it is compatible with Dart 2 SDKs.
  ///
  /// The following conditions must be true:
  /// - it has an SDK constraint,
  /// - supports some of the >=2.0.0 <3.0.0 range,
  /// - does not support any of the >=3.0.0 range,
  final bool isDart2Compatible;

  final bool hasOptedIntoNullSafety;

  SdkConstraintStatus._({
    required this.hasConstraint,
    required this.enablesDart2Latest,
    required this.isDart2Compatible,
    required this.hasOptedIntoNullSafety,
  });

  // TODO: remove [packageName] in a future breaking release.
  factory SdkConstraintStatus.fromSdkVersion(
    VersionConstraint? constraint, [
    // ignore: avoid_unused_constructor_parameters
    String? packageName,
  ]) {
    final hasConstraint =
        constraint != null && !constraint.isAny && !constraint.isEmpty;
    final enablesDart2 = hasConstraint && constraint!.allowsAny(_range2);
    final enablesFutureVersions =
        hasConstraint && constraint!.allowsAny(_futureRange);
    final hasOptedIntoNullSafety = hasConstraint &&
        constraint is VersionRange &&
        constraint.min != null &&
        isNullSafety(constraint.min!);
    return SdkConstraintStatus._(
      hasConstraint: hasConstraint,
      enablesDart2Latest: hasConstraint && constraint!.allowsAny(_range2Latest),
      isDart2Compatible:
          hasConstraint && enablesDart2 && !enablesFutureVersions,
      hasOptedIntoNullSafety: hasOptedIntoNullSafety,
    );
  }
}
