library pana.platform;

import 'dart:collection';
import 'package:source_gen/generators/json_serializable.dart';

import 'pubspec.dart';

part 'platform.g.dart';

abstract class PlatformFlags {
  /// Denotes a package that references Flutter in `pubspec.yaml`.
  static const String flutter = 'flutter';

  /// Denotes a library that depends on a native extensions via `dart-ext:`
  static const String dartExtension = 'dart-ext';

  /// Denotes a library that depends on pkg/angular or pkg/angular2
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
      package.uses.contains(PlatformFlags.flutter) &&
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
      (uses.contains(PlatformFlags.flutter) && !worksInFlutter) ||
      (uses.contains(PlatformFlags.dartExtension) && !worksInStandalone);

  bool get worksEverywhere =>
      worksInBrowser && worksInStandalone && worksInFlutter;

  bool get worksAnywhere =>
      worksInBrowser || worksInStandalone || worksInFlutter;

  bool get worksInBrowser =>
      _hasNoUseOf(
          [PlatformFlags.flutter, 'dart:ui', PlatformFlags.dartExtension]) &&
      (_webPackages.any(uses.contains) || _hasNoUseOf(['dart:io']));

  bool get worksInStandalone =>
      _hasNoUseOf(_webAnd(['dart:ui', PlatformFlags.flutter]));

  bool get worksInFlutter => _hasNoUseOf(_webAnd([
        'dart:mirrors',
        PlatformFlags.dartExtension,
      ]));

  bool _hasNoUseOf(Iterable<String> platforms) =>
      !platforms.any((p) => uses.contains(p));
}

PlatformInfo classifyPubspec(Pubspec pubspec) {
  final Set<String> uses = new Set();
  if (pubspec.hasFlutterKey || pubspec.dependsOnFlutterSdk) {
    uses.add(PlatformFlags.flutter);
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
  Set<String> uses = new SplayTreeSet<String>();

  uses.addAll(libs.where((l) => _dartLibRegexp.hasMatch(l)));

  if (libs.any((String lib) => lib.startsWith('dart-ext:'))) {
    uses.add(PlatformFlags.dartExtension);
  }

  // packages
  if (libs.any((p) => p.startsWith(_angularRegexp))) {
    uses.add(PlatformFlags.angular);
  }

  return new PlatformInfo(uses);
}

final _angularRegexp = new RegExp(r"package:angular2?/");

final _dartLibRegexp = new RegExp(r"^dart:[a-z_]+$");

Iterable<String> _webAnd(Iterable<String> other) =>
    [_webPackages, other].expand((s) => s);

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
