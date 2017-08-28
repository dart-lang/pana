library pana.platform;

import 'dart:collection';
import 'package:json_serializable/annotations.dart';

import 'pubspec.dart';

part 'platform.g.dart';

class PubspecPlatform {
  final String description;

  static const PubspecPlatform flutter =
      const PubspecPlatform._(PlatformFlags.flutter);

  static const PubspecPlatform undefined =
      const PubspecPlatform._(PlatformFlags.undefined);

  bool get isFlutter => description == flutter.description;

  const PubspecPlatform._(this.description);

  factory PubspecPlatform.fromJson(String value) {
    switch (value) {
      case PlatformFlags.flutter:
        return flutter;
      case PlatformFlags.undefined:
        return undefined;
      default:
        throw new ArgumentError.value(value, 'value', 'Not a supported value.');
    }
  }

  String toJson() => description;

  String toString() => 'PubspecPlatform: $description';
}

abstract class PlatformFlags {
  /// Package uses or depends on Flutter.
  static const String flutter = 'flutter';

  /// Package uses or depends on a native extensions via `dart-ext:`
  static const String dartExtension = 'dart-ext';

  /// Package works everywhere.
  static const String everywhere = 'everywhere';

  /// Package's platform is unspecified.
  static const String undefined = 'undefined';

  /// Package's dependencies are in conflict, won't work.
  static const String conflict = 'conflict';

  /// Package is available in server applications.
  static const String server = 'server';

  /// Package is available in web applications.
  static const String web = 'web';
}

@JsonSerializable()
class PlatformSummary extends Object with _$PlatformSummarySerializerMixin {
  final PubspecPlatform pubspec;
  final Map<String, PlatformInfo> libraries;

  PlatformSummary(this.pubspec, this.libraries);

  factory PlatformSummary.fromJson(Map<String, dynamic> json) =>
      _$PlatformSummaryFromJson(json);

  bool get hasConflict =>
      libraries.values.any((p) => p.hasConflict) || _conflictsFlutter;

  bool get _conflictsFlutter =>
      pubspec.isFlutter && libraries.values.any((p) => !p.worksOnFlutter);

  String get primaryLibrary {
    String pkgName;
    return libraries.keys.firstWhere((path) {
      var uri = Uri.parse(path);
      assert(uri.pathSegments.length >= 2);
      if (pkgName == null) {
        pkgName = uri.pathSegments[0];
      } else {
        assert(uri.pathSegments[0] == pkgName);
      }

      if (uri.scheme == 'asset') {
        return false;
      }
      assert(uri.scheme == 'package');

      return uri.pathSegments.length == 2 &&
          uri.pathSegments[1] == '$pkgName.dart';
    }, orElse: () => null);
  }

  String get description => fullDescription.description;

  PlatformDescription get fullDescription {
    if (pubspec.isFlutter) {
      if (libraries.values.every((pi) => pi.worksOnFlutter)) {
        return new PlatformDescription(
            PlatformFlags.flutter, 'pubspec reference with no conflicts');
      }
      assert(hasConflict);
      return new PlatformDescription(
          PlatformFlags.conflict, 'flutter package with library conflicts');
    }

    assert(pubspec == PubspecPlatform.undefined);

    if (libraries.isEmpty) {
      return new PlatformDescription(PlatformFlags.undefined, 'no libraries!');
    }

    var items = (libraries.values.expand((pi) => pi.descriptionSet).toList()
          ..sort())
        .toSet();

    if (items.length == 1) {
      return new PlatformDescription(items.single, 'All libraries agree');
    }

    var primaryLibrary = this.primaryLibrary;

    if (primaryLibrary != null) {
      var primaryPlatform = libraries[primaryLibrary];
      var primaryPlatformSet = primaryPlatform.descriptionSet;
      if (primaryPlatformSet.length == 1) {
        return new PlatformDescription(
            primaryPlatformSet.single, 'primary library - `$primaryLibrary');
      }
    }

    // If the primary library search fails, go back to the roll-up of all
    // platforms. See if excluding `everywhere` leads us to something more
    // specific.

    var everythingRemoved = false;
    if (items.length > 1) {
      everythingRemoved = items.remove(PlatformFlags.everywhere);

      if (items.length == 1) {
        return new PlatformDescription(
            items.single, 'one library with an opinion - $everythingRemoved');
      }
    }

    if (items.isEmpty) {
      return new PlatformDescription(
          PlatformFlags.undefined, 'no library opinions? - $everythingRemoved');
    }

    return new PlatformDescription(items.join(','), 'all of the above');
  }
}

@JsonSerializable()
class PlatformDescription extends Object
    with _$PlatformDescriptionSerializerMixin {
  final String description;
  final String details;

  PlatformDescription(this.description, this.details);

  factory PlatformDescription.fromJson(Map<String, dynamic> json) =>
      _$PlatformDescriptionFromJson(json);
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

  Set<String> get descriptionSet {
    if (worksEverywhere) {
      return new Set.from([PlatformFlags.everywhere]);
    }

    var items = <String>[];
    if (worksOnFlutter) {
      items.add(PlatformFlags.flutter);
    }

    if (worksOnServer) {
      items.add(PlatformFlags.server);
    }

    if (worksOnWeb) {
      items.add(PlatformFlags.web);
    }

    if (items.isEmpty) {
      assert(hasConflict);
      return new Set.from([PlatformFlags.conflict]);
    }

    assert(!hasConflict);

    return (items..sort()).toSet();
  }

  String get description => descriptionSet.join(', ');

  @override
  String toString() => 'PlatformInfo: $description';

  bool _hasNoUseOf(Iterable<String> platforms) =>
      !platforms.any((p) => uses.contains(p));
}

PubspecPlatform classifyPubspec(Pubspec pubspec) {
  if (pubspec.hasFlutterKey || pubspec.dependsOnFlutterSdk) {
    return PubspecPlatform.flutter;
  }
  return PubspecPlatform.undefined;
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
