// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
