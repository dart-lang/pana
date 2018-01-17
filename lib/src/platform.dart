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
}

abstract class ComponentNames {
  /// Flutter and related libraries
  static const String flutter = 'flutter';

  /// dart:html and related libraries
  static const String html = 'html';

  /// dart:js and related libraries
  static const String js = 'js';

  /// dart:io and related libraries
  static const String io = 'io';

  /// dart:nativewrappers and related libraries
  static const String nativewrappers = 'nativewrappers';

  /// dart:mirrors and related libraries
  static const String mirrors = 'mirrors';
}

class ComponentDef {
  final String name;

  /// The packages that this component uses.
  final List<String> dependencies;

  const ComponentDef(this.name, this.dependencies);

  /// Flutter and related libraries
  static const ComponentDef flutter = const ComponentDef(
    ComponentNames.flutter,
    const <String>[
      'dart:ui',
      'package:flutter',
    ],
  );

  /// dart:html and related libraries
  static const ComponentDef html = const ComponentDef(
    ComponentNames.html,
    const <String>[
      'dart:html',
      'dart:indexed_db',
      'dart:svg',
      'dart:web_audio',
      'dart:web_gl',
      'dart:web_sql',
    ],
  );

  /// dart:js and related libraries
  static const ComponentDef js = const ComponentDef(
    ComponentNames.js,
    const <String>[
      'dart:js',
      'dart:js_util',
    ],
  );

  /// dart:io and related libraries
  static const ComponentDef io = const ComponentDef(
    ComponentNames.io,
    const <String>[
      'dart:io',
    ],
  );

  /// dart:nativewrappers and related libraries
  static const ComponentDef nativewrappers = const ComponentDef(
    ComponentNames.nativewrappers,
    const <String>[
      'dart:nativewrappers',
      'dart-ext:',
    ],
  );

  /// dart:mirrors and related libraries
  static const ComponentDef mirrors = const ComponentDef(
    ComponentNames.mirrors,
    const <String>[
      'dart:mirrors',
    ],
  );

  static const List<ComponentDef> values = const <ComponentDef>[
    ComponentDef.flutter,
    ComponentDef.html,
    ComponentDef.js,
    ComponentDef.io,
    ComponentDef.nativewrappers,
    ComponentDef.mirrors,
  ];

  static List<ComponentDef> detectComponents(Iterable<String> dependencies) {
    final deps = _normalizeDependencies(dependencies);
    return values.where((c) => c.dependencies.any(deps.contains)).toList();
  }
}

class PlatformDef {
  final String name;
  final List<ComponentDef> required;
  final List<ComponentDef> forbidden;

  const PlatformDef(this.name, this.required, this.forbidden);

  /// Package uses or depends on Flutter.
  static const PlatformDef flutter = const PlatformDef(
    PlatformNames.flutter,
    const <ComponentDef>[
      ComponentDef.flutter,
    ],
    const <ComponentDef>[
      ComponentDef.html,
      ComponentDef.js,
      ComponentDef.mirrors,
      ComponentDef.nativewrappers,
    ],
  );

  /// Package is available in server applications.
  static const PlatformDef server = const PlatformDef(
    PlatformNames.server,
    const <ComponentDef>[
      ComponentDef.io,
      ComponentDef.nativewrappers,
    ],
    const <ComponentDef>[
      ComponentDef.flutter,
      ComponentDef.html,
      ComponentDef.js,
    ],
  );

  /// Package is available in web applications.
  static const PlatformDef web = const PlatformDef(
    PlatformNames.web,
    const <ComponentDef>[
      ComponentDef.html,
      ComponentDef.js,
    ],
    const <ComponentDef>[
      ComponentDef.flutter,
      ComponentDef.nativewrappers,
    ],
  );

  static const List<PlatformDef> values = const <PlatformDef>[
    PlatformDef.flutter,
    PlatformDef.server,
    PlatformDef.web,
  ];

  static List<PlatformStatus> detectPlatforms(List<ComponentDef> components) =>
      values.map((p) => p.detectStatus(components)).toList();

  PlatformStatus detectStatus(List<ComponentDef> components) {
    final isAllowed =
        components.isEmpty || components.every((c) => !forbidden.contains(c));
    final isUsed = components.any((c) => required.contains(c));
    return new PlatformStatus(name, isAllowed, isUsed);
  }
}

@JsonSerializable()
class PlatformStatus extends Object with _$PlatformStatusSerializerMixin {
  final String name;
  final bool isAllowed;
  final bool isUsed;

  PlatformStatus(this.name, this.isAllowed, this.isUsed);
  factory PlatformStatus.fromJson(Map<String, dynamic> json) =>
      _$PlatformStatusFromJson(json);

  bool get hasConflict => !isAllowed && isUsed;
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

  factory _LibInspector(Set<String> dependencies) =>
      new _LibInspector._(_normalizeDependencies(dependencies));

  bool get hasConflict =>
      (!worksAnywhere) ||
      (_deps.contains(PlatformNames.flutter) && !worksOnFlutter) ||
      ((_deps.contains('dart-ext:') || _deps.contains('dart:nativewrappers')) &&
          !worksOnServer);

  bool get worksEverywhere => worksOnWeb && worksOnServer && worksOnFlutter;

  bool get worksAnywhere => worksOnWeb || worksOnServer || worksOnFlutter;

  bool get worksOnWeb =>
      _hasNoUseOf([
        PlatformNames.flutter,
        'dart:ui',
        'dart-ext:',
        'dart:nativewrappers',
      ]) &&
      (_webPackages.any(_deps.contains) || _hasNoUseOf(['dart:io']));

  bool get worksOnServer =>
      _hasNoUseOf(_webAnd(['dart:ui', PlatformNames.flutter]));

  bool get worksOnFlutter => _hasNoUseOf(_webAnd([
        'dart:mirrors',
        'dart-ext:',
        'dart:nativewrappers',
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

Set<String> _normalizeDependencies(Iterable<String> dependencies) {
  var deps = new Set<String>();
  deps.addAll(dependencies);
  // maps `package:pkg/lib.dart` -> `package:pkg`
  deps.addAll(dependencies.map((dep) => dep.split('/').first));
  // maps prefixes `dart:io` -> `dart:`, `dart-ext:whatever` -> `dart-ext`
  deps.addAll(dependencies.map((dep) => '${dep.split(':').first}:'));
  return deps;
}
