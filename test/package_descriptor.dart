// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:test_descriptor/test_descriptor.dart' as d;

/// Convenience for creating a descriptor of a package.
d.DirectoryDescriptor packageWithPathDeps(String name,
    {String sdkConstraint,
    List<String> dependencies = const [],
    List<d.Descriptor> lib = const [],
    Map pubspecExtras = const {},
    List<d.Descriptor> extraFiles = const []}) {
  final pubspec = json.encode(
    {
      'name': name,
      if (sdkConstraint != null) 'environment': {'sdk': sdkConstraint},
      'dependencies': {
        for (final dep in dependencies) dep: {'path': '../$dep'}
      },
      ...pubspecExtras,
    },
  );
  // TODO(sigurdm): write a package_config.json or use `dart pub get`.da
  final packages = [
        '$name:lib/',
        for (final dep in dependencies) '$dep:../$dep/lib/'
      ].join('\n') +
      '\n';
  return d.dir(name, [
    d.file('.packages', packages),
    d.file('pubspec.yaml', pubspec),
    d.dir('lib', lib),
    ...extraFiles,
  ]);
}

/// Convenience for creating a descriptor of a package.
d.DirectoryDescriptor package(String name,
    {String sdkConstraint,
    Map<String, Object> dependencies = const {},
    List<d.Descriptor> lib = const [],
    Map pubspecExtras = const {},
    List<d.Descriptor> extraFiles = const []}) {
  final pubspec = json.encode(
    {
      'name': name,
      if (sdkConstraint != null) 'environment': {'sdk': sdkConstraint},
      'dependencies': dependencies,
      ...pubspecExtras,
    },
  );
  return d.dir(name, [
    d.file('pubspec.yaml', pubspec),
    d.dir('lib', lib),
    ...extraFiles,
  ]);
}
