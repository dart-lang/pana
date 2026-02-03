// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:test_descriptor/test_descriptor.dart' as d;

/// Convenience for creating a descriptor of a package.
d.DirectoryDescriptor packageWithPathDeps(
  String name, {
  String? sdkConstraint,
  List<String> dependencies = const [],
  List<d.Descriptor> lib = const [],
  Map<String, Object> pubspecExtras = const {},
  List<d.Descriptor> extraFiles = const [],
}) {
  final pubspec = json.encode({
    'name': name,
    if (sdkConstraint != null) 'environment': {'sdk': sdkConstraint},
    'dependencies': {
      for (final dep in dependencies) dep: {'path': '../$dep'},
    },
    ...pubspecExtras,
  });
  final packageConfig = json.encode({
    'configVersion': 2,
    'packages': [
      {
        'name': name,
        'rootUri': '..',
        'packageUri': 'lib/',
        'languageVersion': '2.12',
      },
      for (final dep in dependencies)
        {
          'name': dep,
          'rootUri': '../../$dep',
          'packageUri': 'lib/',
          // TODO(sigurdm) somehow communicate the real language-version
          // Our analysis uses the bound in pubspec.yaml, so this doesn't cause
          // problems yet.
          'languageVersion': '2.12',
        },
    ],
  });
  return d.dir(name, [
    d.dir('.dart_tool', [d.file('package_config.json', packageConfig)]),
    d.file('pubspec.yaml', pubspec),
    d.dir('lib', lib),
    ...extraFiles,
  ]);
}

/// Convenience for creating a descriptor of a package.
d.DirectoryDescriptor package(
  String name, {
  String? version,
  String? sdkConstraint,
  Map<String, Object> dependencies = const {},
  List<d.Descriptor> lib = const [],
  Map<String, Object> pubspecExtras = const {},
  List<d.Descriptor> extraFiles = const [],
}) {
  final pubspec = json.encode({
    'name': name,
    'version': ?version,
    if (sdkConstraint != null) 'environment': {'sdk': sdkConstraint},
    'dependencies': dependencies,
    ...pubspecExtras,
  });
  return d.dir(name, [
    d.file('pubspec.yaml', pubspec),
    d.dir('lib', lib),
    ...extraFiles,
  ]);
}
