library pana.platform;

import 'package:source_gen/generators/json_serializable.dart';

import 'pubspec.dart';

part 'platform.g.dart';

abstract class KnownPlatforms {
  static const String browser = 'browser';
  static const String console = 'console';
  static const String flutter = 'flutter';
  static const String mirrors = 'mirrors';

  static const String angular = 'angular';
}

class PlatformSummary {
  final Platform package;
  final Map<String, Platform> libraries;

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
class Platform extends Object with _$PlatformSerializerMixin {
  final List<String> uses;

  Platform._(this.uses);

  factory Platform(Iterable<String> uses) =>
      new Platform._((uses ?? []).toList()..sort());

  factory Platform.fromJson(Map<String, dynamic> map) =>
      _$PlatformFromJson(map);

  bool get hasConflict =>
      (!worksAnywhere) ||
      (uses.contains(KnownPlatforms.flutter) && !worksInFlutter);

  bool get worksEverywhere =>
      worksInBrowser && worksInConsole && worksInFlutter;

  bool get worksAnywhere => worksInBrowser || worksInConsole || worksInFlutter;

  bool get worksInBrowser =>
      _hasNoUseOf([KnownPlatforms.flutter]) &&
      (uses.contains(KnownPlatforms.browser) ||
          _hasNoUseOf([KnownPlatforms.console]));

  bool get worksInConsole =>
      _hasNoUseOf([KnownPlatforms.browser, KnownPlatforms.flutter]);

  bool get worksInFlutter =>
      _hasNoUseOf([KnownPlatforms.browser, KnownPlatforms.mirrors]);

  bool _hasNoUseOf(Iterable<String> platforms) =>
      !platforms.any((p) => uses.contains(p));
}

Platform classifyPubspec(Pubspec pubspec) {
  final Set<String> uses = new Set();
  if (pubspec.hasFlutterKey || pubspec.dependsOnFlutterSdk) {
    uses.add(KnownPlatforms.flutter);
  }
  return new Platform(uses);
}

PlatformSummary classifyPlatforms(
    Pubspec pubspec, Map<String, List<String>> transitiveLibs) {
  final Platform package = classifyPubspec(pubspec);
  return new PlatformSummary(
      package,
      new Map.fromIterable(transitiveLibs.keys ?? [],
          value: (key) => classifyPlatform(transitiveLibs[key])));
}

Platform classifyPlatform(Iterable<String> dependencies) {
  Set<String> libs = dependencies.toSet();
  Set<String> uses = new Set();

  if (_webPackages.any(libs.contains)) {
    uses.add(KnownPlatforms.browser);
  }

  if (libs.contains('dart:io')) {
    uses.add(KnownPlatforms.console);
  }

  if (libs.contains('dart:ui')) {
    uses.add(KnownPlatforms.flutter);
  }

  if (libs.contains('dart:mirrors')) {
    uses.add(KnownPlatforms.mirrors);
  }

  // packages
  if (libs.any((p) => p.startsWith('package:angular2/'))) {
    uses.add(KnownPlatforms.angular);
  }

  return new Platform(uses);
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
