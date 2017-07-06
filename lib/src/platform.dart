library pana.platform;

import 'package:source_gen/generators/json_serializable.dart';

import 'pubspec.dart';

part 'platform.g.dart';

abstract class KnownPlatforms {
  static const String browser = 'browser';
  static const String standalone = 'standalone';
  static const String flutter = 'flutter';
  static const String mirrors = 'mirrors';

  /// Native extensions (Dart VM with C/C++ code).
  static const String native = 'native';

  static const String angular = 'angular';
}

class PlatformSummary {
  final PlatformInfo package;
  final Map<String, PlatformInfo> libraries;

  PlatformSummary(this.package, this.libraries);

  bool get hasConflict =>
      package.hasConflict ||
      libraries.values.any((p) => p.hasConflict) ||
      _conflictsFlutter;

  bool get _conflictsFlutter =>
      package.uses.contains(KnownPlatforms.flutter) &&
      libraries.values.any((p) => !p.worksInFlutter);
}

@JsonSerializable()
class PlatformInfo extends Object with _$PlatformInfoSerializerMixin {
  final List<String> uses;

  PlatformInfo._(this.uses);

  factory PlatformInfo(Iterable<String> uses) =>
      new PlatformInfo._((uses?.toList() ?? <String>[])..sort());

  factory PlatformInfo.fromJson(Map<String, dynamic> map) =>
      _$PlatformFromJson(map);

  bool get hasConflict =>
      (!worksAnywhere) ||
      (uses.contains(KnownPlatforms.flutter) && !worksInFlutter) ||
      (uses.contains(KnownPlatforms.native) && !worksInStandalone);

  bool get worksEverywhere =>
      worksInBrowser && worksInStandalone && worksInFlutter;

  bool get worksAnywhere =>
      worksInBrowser || worksInStandalone || worksInFlutter;

  bool get worksInBrowser =>
      _hasNoUseOf([KnownPlatforms.flutter, KnownPlatforms.native]) &&
      (uses.contains(KnownPlatforms.browser) ||
          _hasNoUseOf([KnownPlatforms.standalone]));

  bool get worksInStandalone =>
      _hasNoUseOf([KnownPlatforms.browser, KnownPlatforms.flutter]);

  bool get worksInFlutter => _hasNoUseOf([
        KnownPlatforms.browser,
        KnownPlatforms.mirrors,
        KnownPlatforms.native,
      ]);

  bool _hasNoUseOf(Iterable<String> platforms) =>
      !platforms.any((p) => uses.contains(p));
}

PlatformInfo classifyPubspec(Pubspec pubspec) {
  final Set<String> uses = new Set();
  if (pubspec.hasFlutterKey || pubspec.dependsOnFlutterSdk) {
    uses.add(KnownPlatforms.flutter);
  }
  return new PlatformInfo(uses);
}

PlatformSummary classifyPlatforms(
    Pubspec pubspec, Map<String, List<String>> transitiveLibs) {
  final PlatformInfo package = classifyPubspec(pubspec);
  return new PlatformSummary(
      package,
      new Map.fromIterable(transitiveLibs.keys ?? <String>[],
          value: (key) => classifyPlatform(transitiveLibs[key])));
}

PlatformInfo classifyPlatform(Iterable<String> dependencies) {
  Set<String> libs = dependencies.toSet();
  Set<String> uses = new Set();

  if (_webPackages.any(libs.contains)) {
    uses.add(KnownPlatforms.browser);
  }

  if (libs.contains('dart:io')) {
    uses.add(KnownPlatforms.standalone);
  }

  if (libs.contains('dart:ui')) {
    uses.add(KnownPlatforms.flutter);
  }

  if (libs.contains('dart:mirrors')) {
    uses.add(KnownPlatforms.mirrors);
  }

  if (libs.any((String lib) => lib.startsWith('dart-ext:'))) {
    uses.add(KnownPlatforms.native);
  }

  // packages
  if (libs.any((p) => p.startsWith('package:angular2/'))) {
    uses.add(KnownPlatforms.angular);
  }

  return new PlatformInfo(uses);
}

const List<String> _webPackages = const [
  'dart:html',
  'dart:indexed_db',
  'dart:js',
  'dart:js_util',
  'dart:svg',
  'dart:web_audio',
  'dart:web_gl',
  'dart:web_sql',
];
