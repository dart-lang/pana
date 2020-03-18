library pana.platform;

import 'messages.dart' show buildSample;
import 'model.dart'
    show ComponentNames, DartPlatform, PlatformNames, PlatformUse;
import 'pubspec.dart';

class ComponentDef {
  final String name;

  /// The packages that this component uses.
  final List<String> dependencies;

  const ComponentDef(this.name, this.dependencies);

  /// Flutter and related libraries
  static const ComponentDef flutter = ComponentDef(
    ComponentNames.flutter,
    <String>[
      'dart:ui',
      'package:flutter',
    ],
  );

  /// dart:html and related libraries
  static const ComponentDef html = ComponentDef(
    ComponentNames.html,
    <String>[
      'dart:html',
      'dart:indexed_db',
      'dart:svg',
      'dart:web_audio',
      'dart:web_gl',
      'dart:web_sql',
    ],
  );

  /// dart:js and related libraries
  static const ComponentDef js = ComponentDef(
    ComponentNames.js,
    <String>[
      'dart:js',
      'dart:js_util',
    ],
  );

  /// dart:io and related libraries
  static const ComponentDef io = ComponentDef(
    ComponentNames.io,
    <String>[
      'dart:io',
    ],
  );

  /// dart:isolate and related libraries
  static const ComponentDef isolate = ComponentDef(
    ComponentNames.isolate,
    <String>[
      'dart:isolate',
    ],
  );

  /// dart:nativewrappers and related libraries
  static const ComponentDef nativewrappers = ComponentDef(
    ComponentNames.nativewrappers,
    <String>[
      'dart:nativewrappers',
      'dart-ext:',
    ],
  );

  /// dart:nativewrappers and related libraries
  static const ComponentDef build = ComponentDef(
    ComponentNames.build,
    <String>[
      'package:barback',
      'package:build',
    ],
  );

  /// dart:mirrors and related libraries
  static const ComponentDef mirrors = ComponentDef(
    ComponentNames.mirrors,
    <String>[
      'dart:mirrors',
    ],
  );

  static const List<ComponentDef> values = <ComponentDef>[
    ComponentDef.flutter,
    ComponentDef.html,
    ComponentDef.js,
    ComponentDef.io,
    ComponentDef.isolate,
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
  static const PlatformDef flutter = PlatformDef(
    PlatformNames.flutter,
    <ComponentDef>[
      ComponentDef.flutter,
    ],
    <ComponentDef>[
      ComponentDef.html,
      ComponentDef.js,
      ComponentDef.mirrors,
      ComponentDef.nativewrappers,
    ],
  );

  /// Package is available in web applications.
  static const PlatformDef web = PlatformDef(
    PlatformNames.web,
    <ComponentDef>[
      ComponentDef.html,
      ComponentDef.js,
    ],
    <ComponentDef>[
      ComponentDef.flutter,
      ComponentDef.isolate,
      ComponentDef.nativewrappers,
    ],
  );

  /// Fallback platform
  static const PlatformDef other = PlatformDef(
    PlatformNames.other,
    <ComponentDef>[
      ComponentDef.js,
      ComponentDef.io,
      ComponentDef.isolate,
      ComponentDef.nativewrappers,
      ComponentDef.mirrors,
    ],
    <ComponentDef>[
      ComponentDef.flutter,
      ComponentDef.html,
    ],
  );

  static const List<PlatformDef> values = <PlatformDef>[
    PlatformDef.flutter,
    PlatformDef.web,
    PlatformDef.other,
  ];

  static Map<String, PlatformUse> detectUses(List<ComponentDef> components) {
    // ignore: prefer_for_elements_to_map_fromIterable
    return Map<String, PlatformUse>.fromIterable(
      values,
      key: (p) => (p as PlatformDef).name,
      value: (p) => (p as PlatformDef).detectUse(components),
    );
  }

  PlatformUse detectUse(List<ComponentDef> components) {
    final isUsed = components.any(required.contains);
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

PlatformUse _getPlatformStatus(bool isAllowed, bool isUsed) {
  if (isAllowed) {
    return isUsed ? PlatformUse.used : PlatformUse.allowed;
  } else {
    return isUsed ? PlatformUse.conflict : PlatformUse.forbidden;
  }
}

DartPlatform classifyPkgPlatform(
    Pubspec pubspec, Map<String, List<String>> transitiveLibs) {
  if (transitiveLibs == null) {
    return DartPlatform.conflict('Failed to scan transitive libraries.');
  }

  final libraries = Map<String, DartPlatform>.fromIterable(
      transitiveLibs.keys ?? <String>[],
      value: (key) => classifyLibPlatform(transitiveLibs[key]));

  String formatConflictSample(String s) {
    final components = libraries[s].components.map((s) => '`$s`').join(', ');
    return '`$s` (components: $components)';
  }

  final allComponentsSet = <String>{};
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
      final withFlutter = Set<String>.from(allComponentsSet)
        ..add(ComponentNames.flutter);
      return DartPlatform.fromComponents(
        withFlutter.toList()..sort(),
        reason: 'References Flutter, and has no conflicting libraries.',
      );
    } else {
      flutterConflicts.sort();
      final sample = buildSample(flutterConflicts.map(formatConflictSample));
      return DartPlatform.conflict(
          'References Flutter, but has conflicting libraries: $sample.');
    }
  }

  final primaryLibrary =
      _selectPrimaryLibrary(pubspec, transitiveLibs.keys.toSet());
  if (primaryLibrary != null) {
    final primaryPlatform = libraries[primaryLibrary];
    if (primaryPlatform.worksEverywhere) {
      return DartPlatform.everywhere(
          'No platform restriction found in primary library `$primaryLibrary`.');
    } else {
      final componentsFound =
          primaryPlatform.components.map((name) => '`$name`').join(', ');
      return DartPlatform.fromComponents(primaryPlatform.components,
          reason:
              'Primary library: `$primaryLibrary` with components: $componentsFound.');
    }
  }

  if (transitiveLibs.isEmpty) {
    return DartPlatform.everywhere('No libraries.');
  }

  if (allComponentsSet.isEmpty) {
    return DartPlatform.everywhere(
        'No platform restriction found in libraries.');
  }

  final conflicts =
      libraries.keys.where((key) => libraries[key].hasConflict).toList();
  if (conflicts.isNotEmpty) {
    conflicts.sort();
    final sample = buildSample(conflicts.map(formatConflictSample));
    return DartPlatform.conflict('Conflicting libraries: $sample.');
  }

  final componentsFound = allComponentNames.map((name) => '`$name`').join(', ');
  return DartPlatform.fromComponents(allComponentNames,
      reason: 'Platform components identified in package: $componentsFound.');
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
  return DartPlatform(componentNames, platforms);
}

Set<String> _normalizeDependencies(Iterable<String> dependencies) {
  var deps = <String>{};
  deps.addAll(dependencies);
  // maps `package:pkg/lib.dart` -> `package:pkg`
  deps.addAll(dependencies.map((dep) => dep.split('/').first));
  // maps prefixes `dart:io` -> `dart:`, `dart-ext:whatever` -> `dart-ext:`
  deps.addAll(dependencies.map((dep) => '${dep.split(':').first}:'));
  return deps;
}
