import 'dart:io';

import 'package:path/path.dart' as p;

import 'pubspec.dart';

Pubspec pubspecFromDir(String packageDir) {
  final path = p.join(packageDir, 'pubspec.yaml');
  final file = File(path);
  String content;
  try {
    content = file.readAsStringSync();
  } on IOException catch (e) {
    throw Exception('Couldn\'t read pubspec.yaml in $packageDir. $e');
  }
  return Pubspec.parseYaml(content, sourceUrl: path);
}
