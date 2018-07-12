import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart' as pubspek show Pubspec;
import 'package:pubspec_parse/pubspec_parse.dart' hide Pubspec;
import 'package:yaml/yaml.dart' as yaml;

import 'utils.dart';

final _dartDevRange = new VersionConstraint.parse('>=1.25.0 <=2.0.0-dev.99.0');
final _dart2First = new Version.parse('2.0.0');

class Pubspec {
  final pubspek.Pubspec _inner;
  final Map _content;

  Set<String> _dependentSdks;

  Pubspec(Map content)
      : _inner = new pubspek.Pubspec.fromJson(content),
        this._content = content;

  factory Pubspec.parseFromDir(String packageDir) {
    var content = getPubspecContent(packageDir);
    if (content == null) {
      throw new Exception("Couldn't find a pubspec.yaml in $packageDir.");
    }
    return new Pubspec.parseYaml(content);
  }

  factory Pubspec.parseYaml(String content) =>
      new Pubspec(new Map<String, dynamic>.from(yaml.loadYaml(content) as Map));

  factory Pubspec.fromJson(Map<String, dynamic> json) => new Pubspec(json);

  Map toJson() => _content;

  String get name => _inner.name;
  String get description => _inner.description;

  Version get version => _inner.version;

  List<String> get authors => _inner.authors;

  Map<String, Dependency> get dependencies => _inner.dependencies;

  Map<String, Dependency> get devDependencies => _inner.devDependencies;

  bool dependsOnPackage(String package) =>
      (dependencies?.containsKey(package) ?? false) ||
      (devDependencies?.containsKey(package) ?? false);

  bool get hasFlutterKey => _content.containsKey('flutter');
  bool get hasFlutterPluginKey =>
      hasFlutterKey &&
      _content['flutter'] is Map &&
      _content['flutter']['plugin'] != null;

  bool get dependsOnFlutterSdk => dependentSdks.contains('flutter');
  bool get dependsOnFlutterPackage => dependsOnPackage('flutter');

  bool get usesFlutter =>
      dependsOnFlutterSdk || dependsOnFlutterPackage || hasFlutterKey;

  @deprecated
  bool get isFlutter => usesFlutter;

  Set<String> get dependentSdks {
    if (_dependentSdks == null) {
      _dependentSdks = new SplayTreeSet();
      dependencies?.values?.forEach((value) {
        if (value is SdkDependency) {
          _dependentSdks.add(value.sdk);
        }
      });
      devDependencies?.values?.forEach((value) {
        if (value is SdkDependency) {
          _dependentSdks.add(value.sdk);
        }
      });
      if (_inner.environment != null) {
        final keys = _inner.environment.keys.toList();
        keys.remove('sdk');
        _dependentSdks.addAll(keys);
      }
    }
    return _dependentSdks;
  }

  Set<String> get unknownSdks {
    var unknowns = new Set<String>.from(dependentSdks);
    unknowns.remove('flutter');
    return unknowns;
  }

  bool get hasUnknownSdks => unknownSdks.isNotEmpty;

  String get homepage => _inner.homepage;

  String get documentation => _inner.documentation;

  bool get hasDartSdkConstraint => _inner.environment.containsKey('sdk');

  bool get shouldWarnDart2Constraint {
    final vc = _inner.environment['sdk'];
    if (vc == null) {
      return false;
    }
    final allowsDartDev = vc.allowsAny(_dartDevRange);
    final allowsDart2 = vc.allows(_dart2First);
    return allowsDartDev && !allowsDart2;
  }
}
