import 'dart:collection';

import 'package:yaml/yaml.dart' as yaml;

import 'utils.dart';

class Pubspec {
  final Map<String, dynamic> _data;

  Set<String> _dependentSdks;

  Pubspec(this._data);

  factory Pubspec.parseFromDir(String packageDir) {
    String content = getPubspecContent(packageDir);
    if (content == null) {
      throw new Exception("Couldn't find a pubspec.yaml in $packageDir.");
    }
    return new Pubspec(yaml.loadYaml(content));
  }

  Map<String, dynamic> get dependencies => _data['dependencies'];
  Map<String, dynamic> get devDependencies => _data['dev_dependencies'];

  bool get hasFlutterKey => _data.containsKey('flutter');
  bool get hasFlutterPluginKey =>
      hasFlutterKey &&
      _data['flutter'] is Map &&
      _data['flutter']['plugin'] != null;

  bool get dependsOnFlutterSdk => dependentSdks.contains('flutter');

  bool get dependsOnAnyVersion {
    if (dependencies == null) return false;
    return dependencies.values.any((v) {
      if (v is String) return v == 'any';
      if (v is Map) return v['version'] == 'any';
      return false;
    });
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

  bool get hasUnknownSdks {
    Set<String> sdks = new Set.from(dependentSdks);
    sdks.remove('flutter');
    return sdks.isNotEmpty;
  }
}
