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
}

@JsonSerializable()
class PlatformSummary extends Object with _$PlatformSummarySerializerMixin {
  final PlatformInfo package;
  final Map<String, PlatformInfo> libraries;

  PlatformSummary(this.package, this.libraries);

  factory PlatformSummary.fromJson(Map<String, dynamic> json) =>
      _$PlatformSummaryFromJson(json);

  bool get hasConflict =>
      package.hasConflict ||
      libraries.values.any((p) => p.hasConflict) ||
      _conflictsFlutter;

  bool get _conflictsFlutter =>
      package.uses.contains(PlatformFlags.flutter) &&
      libraries.values.any((p) => !p.worksOnFlutter);
}

@JsonSerializable()
class PlatformInfo extends Object with _$PlatformInfoSerializerMixin {
  final List<String> uses;

  PlatformInfo._(this.uses);

  factory PlatformInfo(Iterable<String> uses) =>
      new PlatformInfo._((uses?.toList() ?? <String>[])..sort());

  factory PlatformInfo.fromJson(Map<String, dynamic> map) =>
      _$PlatformInfoFromJson(map);

  bool get hasConflict =>
      (!worksAnywhere) ||
      (uses.contains(PlatformFlags.flutter) && !worksOnFlutter) ||
      (uses.contains(PlatformFlags.dartExtension) && !worksOnServer);

  bool get worksEverywhere => worksOnWeb && worksOnServer && worksOnFlutter;

  bool get worksAnywhere => worksOnWeb || worksOnServer || worksOnFlutter;

  bool get worksOnWeb =>
      _hasNoUseOf(
          [PlatformFlags.flutter, 'dart:ui', PlatformFlags.dartExtension]) &&
      (_webPackages.any(uses.contains) || _hasNoUseOf(['dart:io']));

  bool get worksOnServer =>
      _hasNoUseOf(_webAnd(['dart:ui', PlatformFlags.flutter]));

  bool get worksOnFlutter => _hasNoUseOf(_webAnd([
        'dart:mirrors',
        PlatformFlags.dartExtension,
      ]));

  String get description {
    if (worksEverywhere) {
      return 'everywhere';
    }

    var items = <String>[];
    if (worksOnFlutter) {
      items.add('flutter');
    }

    if (worksOnServer) {
      items.add('server');
    }

    if (worksOnWeb) {
      items.add('web');
    }

    if (items.isEmpty) {
      assert(hasConflict);
      return 'conflict';
    }

    return items.join(', ');
  }

  @override
  String toString() => 'PlatformInfo: $description';

  bool _hasNoUseOf(Iterable<String> platforms) =>
      !platforms.any((p) => uses.contains(p));
}

PlatformInfo classifyPubspec(Pubspec pubspec) {
  var uses = new Set<String>();
  if (pubspec.hasFlutterKey || pubspec.dependsOnFlutterSdk) {
    uses.add(PlatformFlags.flutter);
  }
  return new PlatformInfo(uses);
}

PlatformSummary classifyPlatforms(
    Pubspec pubspec, Map<String, List<String>> transitiveLibs) {
  var package = classifyPubspec(pubspec);
  return new PlatformSummary(
      package,
      new Map.fromIterable(transitiveLibs.keys ?? <String>[],
          value: (key) => classifyPlatform(transitiveLibs[key])));
}

PlatformInfo classifyPlatform(Iterable<String> dependencies) {
  var libs = dependencies.toSet();
  var uses = new SplayTreeSet<String>();

  uses.addAll(libs.where((l) => _dartLibRegexp.hasMatch(l)));

  if (libs.any((String lib) => lib.startsWith('dart-ext:'))) {
    uses.add(PlatformFlags.dartExtension);
  }

  return new PlatformInfo(uses);
}

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
