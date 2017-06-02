import 'pubspec.dart';

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

class Platform {
  final List<String> uses;

  Platform._(this.uses);

  factory Platform(Iterable<String> uses) =>
      new Platform._((uses ?? []).toList()..sort());

  factory Platform.fromMap(Map<String, dynamic> map) {
    map ??= {};
    return new Platform(map['uses']);
  }

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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uses': uses,
      };
}

PlatformSummary classifyPlatforms(
    Pubspec pubspec, Map<String, List<String>> transitiveLibs) {
  Set<String> uses = new Set();

  bool isFlutterOnly = pubspec.hasFlutterKey || pubspec.dependsOnFlutterSdk;
  if (isFlutterOnly) {
    uses.add(KnownPlatforms.flutter);
  }

  return new PlatformSummary(
      new Platform(uses),
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
