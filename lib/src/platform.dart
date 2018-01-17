library pana.platform;

import 'package:json_annotation/json_annotation.dart';

import 'pubspec.dart';

part 'platform.g.dart';

abstract class PlatformNames {
  /// Package uses or depends on Flutter.
  static const String flutter = 'flutter';

  /// Package is available in server applications.
  static const String server = 'server';

  /// Package is available in web applications.
  static const String web = 'web';

  /// Package uses or depends on a native extensions via `dart-ext:`
  static const String dartExtension = 'dart-ext';
}

@JsonSerializable()
class DartPlatform extends Object with _$DartPlatformSerializerMixin {
  final bool worksEverywhere;

  @JsonKey(includeIfNull: false)
  final List<String> restrictedTo;

  @JsonKey(includeIfNull: false)
  final String reason;

  DartPlatform(this.worksEverywhere, this.restrictedTo, this.reason);

  factory DartPlatform.conflict(String reason) =>
      new DartPlatform(false, null, reason);

  factory DartPlatform.universal({String reason}) =>
      new DartPlatform(true, null, reason);

  factory DartPlatform.withRestrictions(List<String> restrictedTo,
          {String reason}) =>
      new DartPlatform(false, restrictedTo, reason);

  factory DartPlatform.fromJson(Map<String, dynamic> json) =>
      _$DartPlatformFromJson(json);

  bool get worksAnywhere =>
      worksEverywhere || (restrictedTo != null && restrictedTo.isNotEmpty);
  bool get hasConflict => !worksAnywhere;

  bool get worksOnFlutter => _worksOn(PlatformNames.flutter);
  bool get worksOnServer => _worksOn(PlatformNames.server);
  bool get worksOnWeb => _worksOn(PlatformNames.web);

  bool _worksOn(String name) =>
      worksEverywhere || (restrictedTo != null && restrictedTo.contains(name));
}

class _LibInspector {
  final Set<String> _deps;
  _LibInspector._(this._deps);

  factory _LibInspector(Set<String> dependencies) {
    var deps = new Set<String>();

    deps.addAll(dependencies.where((l) => _dartLibRegexp.hasMatch(l)));
    deps.addAll(dependencies.where((l) => _dartPanaLibRegexp.hasMatch(l)));

    if (dependencies.any((String lib) => lib.startsWith('dart-ext:')) ||
        dependencies.contains('dart:nativewrappers')) {
      deps.add(PlatformNames.dartExtension);
    }

    return new _LibInspector._(deps);
  }

  bool get hasConflict =>
      (!worksAnywhere) ||
      (_deps.contains(PlatformNames.flutter) && !worksOnFlutter) ||
      (_deps.contains(PlatformNames.dartExtension) && !worksOnServer);

  bool get worksEverywhere => worksOnWeb && worksOnServer && worksOnFlutter;

  bool get worksAnywhere => worksOnWeb || worksOnServer || worksOnFlutter;

  bool get worksOnWeb =>
      _hasNoUseOf(
          [PlatformNames.flutter, 'dart:ui', PlatformNames.dartExtension]) &&
      (_webPackages.any(_deps.contains) || _hasNoUseOf(['dart:io']));

  bool get worksOnServer =>
      _hasNoUseOf(_webAnd(['dart:ui', PlatformNames.flutter]));

  bool get worksOnFlutter => _hasNoUseOf(_webAnd([
        'dart:mirrors',
        PlatformNames.dartExtension,
      ]));

  bool _hasNoUseOf(Iterable<String> platforms) =>
      !platforms.any((p) => _deps.contains(p));
}

DartPlatform classifyPkgPlatform(
    Pubspec pubspec, Map<String, List<String>> transitiveLibs) {
  if (transitiveLibs == null) {
    return new DartPlatform.conflict('Failed to scan transitive libraries.');
  }
  final libraries = new Map<String, DartPlatform>.fromIterable(
      transitiveLibs.keys ?? <String>[],
      value: (key) => classifyLibPlatform(transitiveLibs[key]));
  final primaryLibrary =
      _selectPrimaryLibrary(pubspec, transitiveLibs.keys.toSet());

  if (pubspec.isFlutter) {
    final flutterConflicts =
        libraries.keys.where((key) => !libraries[key].worksOnFlutter).toList();
    if (flutterConflicts.isNotEmpty) {
      flutterConflicts.sort();
      var sample = flutterConflicts.take(3).map((s) => '`$s`').join(', ');
      if (flutterConflicts.length > 3) {
        sample = '$sample (and ${flutterConflicts.length - 3} more).';
      }
      return new DartPlatform.conflict(
          'References Flutter, but has conflicting libraries: $sample.');
    } else {
      return new DartPlatform.withRestrictions([PlatformNames.flutter],
          reason: 'References Flutter, and has no conflicting libraries.');
    }
  }

  if (libraries.isEmpty) {
    // TODO: if there is a `bin/` asset, maybe this is server-only?
    return new DartPlatform.conflict('No libraries!');
  }

  for (var lib in libraries.keys) {
    final libp = libraries[lib];
    if (libp.hasConflict) {
      return new DartPlatform.conflict('Conflict in library `$lib`.');
    }
  }

  if (libraries.values.every((lp) => lp.worksEverywhere)) {
    return new DartPlatform.universal(
        reason: 'No platform restriction found in libraries.');
  }

  if (primaryLibrary != null && libraries[primaryLibrary].worksEverywhere) {
    return new DartPlatform.universal(
        reason:
            'No platform restriction found in primary library `$primaryLibrary`.');
  }

  final items = libraries.values
      .where((p) => !p.worksEverywhere)
      .expand((p) => p.restrictedTo)
      .toSet();
  if (items.length == 1) {
    return new DartPlatform.withRestrictions([items.single],
        reason: 'All libraries have the same platform restriction.');
  }

  if (primaryLibrary != null) {
    var primaryPlatform = libraries[primaryLibrary];
    if (primaryPlatform.restrictedTo?.length == 1) {
      final platform = primaryPlatform.restrictedTo.single;
      return new DartPlatform.withRestrictions(primaryPlatform.restrictedTo,
          reason:
              'Primary library `$primaryLibrary` is restricted to `$platform`.');
    }
  }

  // If the primary library search fails, go back to the roll-up of all
  // platforms.

  if (items.isEmpty) {
    return new DartPlatform.conflict(
        'Unable to identify platform from libraries (no restriction found).');
  }

  if (items.length == 1) {
    final platform = items.single;
    return new DartPlatform.withRestrictions([items.single],
        reason: 'Libraries are restricted to `$platform`.');
  }

  return new DartPlatform.withRestrictions(items.toList()..sort(),
      reason: 'Multiple platform identified in libraries.');
}

String _selectPrimaryLibrary(Pubspec pubspec, Set<String> libraryUris) {
  final pkg = pubspec.name;
  final primaryCandidates = <String>[
    'package:$pkg/$pkg.dart',
    'package:$pkg/main.dart',
  ];
  return primaryCandidates.firstWhere(libraryUris.contains, orElse: () => null);
}

DartPlatform classifyLibPlatform(Iterable<String> dependencies) {
  final inspector = new _LibInspector(dependencies.toSet());
  if (inspector.hasConflict) {
    return new DartPlatform.conflict('Transitive dependencies in conflict.');
  }
  if (inspector.worksEverywhere) {
    return new DartPlatform.universal();
  }
  final restrictedTo = <String>[];
  if (inspector.worksOnFlutter) restrictedTo.add(PlatformNames.flutter);
  if (inspector.worksOnServer) restrictedTo.add(PlatformNames.server);
  if (inspector.worksOnWeb) restrictedTo.add(PlatformNames.web);
  restrictedTo.sort();
  if (restrictedTo.isEmpty) {
    return new DartPlatform.conflict('Transitive dependencies in conflict.');
  }
  return new DartPlatform.withRestrictions(restrictedTo);
}

final _dartLibRegexp = new RegExp(r"^dart:[a-z_]+$");
final _dartPanaLibRegexp = new RegExp(r"^dart-pana:[a-z_]+$");

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
