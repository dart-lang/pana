library pana.platform;

import 'package:json_annotation/json_annotation.dart';

import 'pubspec.dart';

part 'platform.g.dart';

abstract class PlatformNames {
  /// Package uses or depends on Flutter.
  static const String flutter = 'flutter';

  /// Package is available in web applications.
  static const String web = 'web';

  /// Package is available in web applications.
  static const String other = 'other';
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

  /// Transformers and other build tools.
  static const String build = 'build';

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

  /// dart:nativewrappers and related libraries
  static const ComponentDef build = const ComponentDef(
    ComponentNames.build,
    const <String>[
      'package:barback',
      'package:build',
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
    ComponentDef.build,
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

  /// Fallback platform
  static const PlatformDef other = const PlatformDef(
    PlatformNames.other,
    const <ComponentDef>[
      ComponentDef.js,
      ComponentDef.io,
      ComponentDef.nativewrappers,
      ComponentDef.mirrors,
    ],
    const <ComponentDef>[
      ComponentDef.flutter,
      ComponentDef.html,
    ],
  );

  static const List<PlatformDef> values = const <PlatformDef>[
    PlatformDef.flutter,
    PlatformDef.web,
    PlatformDef.other,
  ];

  static Map<String, PlatformUse> detectUses(List<ComponentDef> components) {
    return new Map<String, PlatformUse>.fromIterable(
      values,
      // ignore: strong_mode_uses_dynamic_as_bottom
      key: (PlatformDef p) => p.name,
      // ignore: strong_mode_uses_dynamic_as_bottom
      value: (PlatformDef p) => p.detectUse(components),
    );
  }

  PlatformUse detectUse(List<ComponentDef> components) {
    final isUsed = components.any((c) => required.contains(c));
    // Default: everything is allowed, except explicitly forbidden components.
    var isAllowed =
        components.isEmpty || components.every((c) => !forbidden.contains(c));
    // Web packages may use dart:io, but only if they use html components too.
    if (isAllowed &&
        name == PlatformNames.web &&
        !isUsed &&
        components.contains(ComponentDef.io)) {
      isAllowed = false;
    }
    return _getPlatformStatus(isAllowed, isUsed);
  }
}

enum PlatformUse {
  /// is allowed, but not used
  allowed,

  /// is allowed AND used
  used,

  /// is forbidden AND used
  conflict,

  /// is forbidden, but not used
  forbidden,
}

PlatformUse _getPlatformStatus(bool isAllowed, bool isUsed) {
  if (isAllowed) {
    return isUsed ? PlatformUse.used : PlatformUse.allowed;
  } else {
    return isUsed ? PlatformUse.conflict : PlatformUse.forbidden;
  }
}

bool _isAllowed(PlatformUse value) =>
    value == PlatformUse.allowed || value == PlatformUse.used;

@JsonSerializable()
class DartPlatform extends Object with _$DartPlatformSerializerMixin {
  @JsonKey(includeIfNull: false)
  final List<String> components;

  @JsonKey(includeIfNull: false)
  final Map<String, PlatformUse> uses;

  @JsonKey(includeIfNull: false)
  final String reason;

  DartPlatform(this.components, this.uses, {this.reason});

  factory DartPlatform.conflict(String reason) =>
      new DartPlatform(null, null, reason: reason);

  factory DartPlatform.fromComponents(List<String> components,
      {String reason}) {
    final defs = components
        .map((c) => ComponentDef.values.singleWhere((def) => def.name == c))
        .toList();
    return new DartPlatform(components, PlatformDef.detectUses(defs),
        reason: reason);
  }

  factory DartPlatform.everywhere(String reason) =>
      new DartPlatform.fromComponents([], reason: reason);

  factory DartPlatform.fromJson(Map<String, dynamic> json) =>
      _$DartPlatformFromJson(json);

  bool get worksEverywhere =>
      uses != null && uses.values.every((s) => _isAllowed(s));
  bool get worksAnywhere =>
      uses != null && uses.values.any((s) => _isAllowed(s));
  bool get hasConflict => !worksAnywhere;

  bool get worksOnFlutter => _worksOn(PlatformNames.flutter);
  bool get worksOnWeb => _worksOn(PlatformNames.web);
  bool get worksOnOther => _worksOn(PlatformNames.other);

  bool get usesFlutter => _uses(PlatformNames.flutter);

  /// Visible for testing only, DO NOT USE in clients.
  String get longPlatformDebug => uses.keys
      .map((k) => '$k: ${uses[k].toString().split('.').last}')
      .join(', ');

  bool _worksOn(String name) => uses != null && _isAllowed(uses[name]);

  bool _uses(String name) => uses != null && uses[name] == PlatformUse.used;
}

DartPlatform classifyPkgPlatform(
    Pubspec pubspec, Map<String, List<String>> transitiveLibs) {
  if (transitiveLibs == null) {
    return new DartPlatform.conflict('Failed to scan transitive libraries.');
  }

  final libraries = new Map<String, DartPlatform>.fromIterable(
      transitiveLibs.keys ?? <String>[],
      value: (key) => classifyLibPlatform(transitiveLibs[key]));

  final conflicts =
      libraries.keys.where((key) => libraries[key].hasConflict).toList();
  if (conflicts.isNotEmpty) {
    conflicts.sort();
    var sample = conflicts.take(3).map((s) => '`$s`').join(', ');
    if (conflicts.length > 3) {
      sample = '$sample (and ${conflicts.length - 3} more).';
    }
    return new DartPlatform.conflict('Conflicting libraries: $sample.');
  }

  final allComponentsSet = new Set<String>();
  libraries.values
      .map((p) => p.components)
      .where((c) => c != null)
      .forEach(allComponentsSet.addAll);
  final allComponentNames = allComponentsSet.toList()..sort();

  final usesFlutter = libraries.values.any((p) => p.usesFlutter);
  if (pubspec.usesFlutter || usesFlutter) {
    final flutterConflicts =
        libraries.keys.where((key) => !libraries[key].worksOnFlutter).toList();
    if (flutterConflicts.isEmpty) {
      final withFlutter = new Set<String>.from(allComponentsSet)
        ..add(ComponentNames.flutter);
      return new DartPlatform.fromComponents(
        withFlutter.toList()..sort(),
        reason: 'References Flutter, and has no conflicting libraries.',
      );
    } else {
      flutterConflicts.sort();
      var sample = flutterConflicts.take(3).map((s) => '`$s`').join(', ');
      if (flutterConflicts.length > 3) {
        sample = '$sample (and ${flutterConflicts.length - 3} more).';
      }
      return new DartPlatform.conflict(
          'References Flutter, but has conflicting libraries: $sample.');
    }
  }

  final primaryLibrary =
      _selectPrimaryLibrary(pubspec, transitiveLibs.keys.toSet());
  if (primaryLibrary != null) {
    final primaryPlatform = libraries[primaryLibrary];
    if (primaryPlatform.worksEverywhere) {
      return new DartPlatform.everywhere(
          'No platform restriction found in primary library `$primaryLibrary`.');
    } else {
      final componentsFound =
          primaryPlatform.components.map((name) => '`$name`').join(', ');
      return new DartPlatform.fromComponents(primaryPlatform.components,
          reason:
              'Primary library: `$primaryLibrary` with components: $componentsFound.');
    }
  }

  if (transitiveLibs.isEmpty) {
    return new DartPlatform.everywhere('No libraries.');
  }

  if (allComponentsSet.isEmpty) {
    return new DartPlatform.everywhere(
        'No platform restriction found in libraries.');
  } else {
    final componentsFound =
        allComponentNames.map((name) => '`$name`').join(', ');
    return new DartPlatform.fromComponents(allComponentNames,
        reason: 'Platform components identified in package: $componentsFound.');
  }
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
  final components = ComponentDef.detectComponents(dependencies);
  final platforms = PlatformDef.detectUses(components);
  final componentNames = components.map((c) => c.name).toList();
  return new DartPlatform(componentNames, platforms);
}

Set<String> _normalizeDependencies(Iterable<String> dependencies) {
  var deps = new Set<String>();
  deps.addAll(dependencies);
  // maps `package:pkg/lib.dart` -> `package:pkg`
  deps.addAll(dependencies.map((dep) => dep.split('/').first));
  // maps prefixes `dart:io` -> `dart:`, `dart-ext:whatever` -> `dart-ext:`
  deps.addAll(dependencies.map((dep) => '${dep.split(':').first}:'));
  return deps;
}
