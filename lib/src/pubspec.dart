class Pubspec {
  final Map<String, dynamic> _data;

  Pubspec(this._data);

  Map<String, dynamic> get dependencies => _data['dependencies'];

  bool get hasFlutterKey => _data.containsKey('flutter');
  bool get hasFlutterPluginKey =>
      hasFlutterKey &&
      _data['flutter'] is Map &&
      _data['flutter']['plugin'] != null;

  bool get dependsOnFlutterSdk {
    if (dependencies == null) return false;
    return dependencies.values
        .any((value) => value is Map && value['sdk'] == 'flutter');
  }

  bool get dependsOnAnyVersion {
    if (dependencies == null) return false;
    return dependencies.values.any((v) {
      if (v is String) return v == 'any';
      if (v is Map) return v['version'] == 'any';
      return false;
    });
  }
}
