import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart' as yaml;

import 'utils.dart';

class Pubspec {
  final Map<String, dynamic> _data;

  Set<String> _dependentSdks;

  Pubspec(this._data);

  factory Pubspec.parseFromDir(String packageDir) {
    var content = getPubspecContent(packageDir);
    if (content == null) {
      throw new Exception("Couldn't find a pubspec.yaml in $packageDir.");
    }
    return new Pubspec.parseYaml(content);
  }

  factory Pubspec.parseYaml(String content) =>
      new Pubspec(yaml.loadYaml(content));

  Map<String, dynamic> get dependencies {
    final deps = _data['dependencies'];
    return deps is Map ? deps : null;
  }

  Map<String, dynamic> get devDependencies {
    final deps = _data['dev_dependencies'];
    return deps is Map ? deps : null;
  }

  bool get hasFlutterKey => _data.containsKey('flutter');
  bool get hasFlutterPluginKey =>
      hasFlutterKey &&
      _data['flutter'] is Map &&
      _data['flutter']['plugin'] != null;

  bool get dependsOnFlutterSdk => dependentSdks.contains('flutter');

  List<String> get unconstrainedDependencies {
    final set = new Set<String>();
    void inspectDependency(String pkg, dynamic v) {
      if (v == null || v == 'any') {
        set.add(pkg);
        return;
      }
      if (v is Map && v.containsKey('version') && !v.containsKey('sdk')) {
        final version = v['version'];
        if (version == null || version == 'any') {
          set.add(pkg);
          return;
        }
      }

      final constraint = v is Map ? v['version'] : v;
      if (constraint is String) {
        final vc = new VersionConstraint.parse(constraint);
        if (vc is VersionRange && vc.max == null) {
          set.add(pkg);
          return;
        }
      }
    }

    dependencies?.forEach(inspectDependency);
    devDependencies?.forEach(inspectDependency);
    return set.toList()..sort();
  }

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
    }
    return _dependentSdks;
  }

  Set<String> get unknownSdks {
    var unknowns = new Set<String>.from(dependentSdks);
    unknowns.remove('flutter');
    return unknowns;
  }

  bool get hasUnknownSdks => unknownSdks.isNotEmpty;
}
