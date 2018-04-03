import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart' as yaml;

import 'utils.dart';

class Pubspec {
  final Map<String, dynamic> _content;

  Set<String> _dependentSdks;

  Pubspec(this._content);

  factory Pubspec.parseFromDir(String packageDir) {
    var content = getPubspecContent(packageDir);
    if (content == null) {
      throw new Exception("Couldn't find a pubspec.yaml in $packageDir.");
    }
    return new Pubspec.parseYaml(content);
  }

  factory Pubspec.parseYaml(String content) =>
      new Pubspec(yaml.loadYaml(content));

  factory Pubspec.fromJson(Map<String, dynamic> json) => new Pubspec(json);

  Map<String, dynamic> toJson() => _content;

  String get name => _content['name'];
  String get description => _content['description'];

  Version get version => new Version.parse(_content['version']);

  List<String> get authors {
    var authors = <String>[];

    if (_content == null) {
      return authors;
    }

    if (_content['author'] != null) {
      authors.add(_content['author']);
    } else if (_content['authors'] != null) {
      authors.addAll(_content['authors'] as List<String>);
    }

    return authors;
  }

  Map<String, dynamic> get dependencies {
    final deps = _content['dependencies'];
    return deps is Map ? deps : null;
  }

  Map<String, dynamic> get devDependencies {
    final deps = _content['dev_dependencies'];
    return deps is Map ? deps : null;
  }

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
        if (value is Map && value['sdk'] != null) {
          _dependentSdks.add(value['sdk']);
        }
      });
      devDependencies?.values?.forEach((value) {
        if (value is Map && value['sdk'] != null) {
          _dependentSdks.add(value['sdk']);
        }
      });
      final environmentMap = _content['environment'];
      if (environmentMap is Map) {
        final List<String> keys = environmentMap.keys.toList();
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

  String get homepage {
    final value = _content['homepage'];
    if (value is String) return value.trim();
    return null;
  }
}
