// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A minimalistic library for declarative description of filesystem entities.
///
/// This is heavily inspired by `package:test_descriptor` which delivers the
/// same functionality, but doesn't enable using the abstracted filesystem from
/// `package:file`.
library descriptor;

import 'dart:collection' show UnmodifiableListView;
import 'dart:convert' show json, utf8;

import 'package:file/file.dart';

/// A declarative description of a filesystem entry.
abstract class Descriptor {
  /// Name of this filesystem entry.
  final String name;

  Descriptor(this.name);

  /// Create this entry in [target].
  Future<void> create(Directory target);
}

/// Descriptor for a directory named [name] containing [contents].
Descriptor dir(String name, List<Descriptor> contents) =>
    _DirectoryDescriptor(name, contents);

/// Descriptor for a file named [name] containing [contents] as [utf8] encoded
/// string.
Descriptor file(String name, String contents) =>
    _FileDescriptor(name, contents);

/// Descriptor for a `pubspec.yaml` file containing [contents] render as
/// JSON (which is a subset of YAML).
Descriptor pubspec(Map<String, Object> contents) =>
    file('pubspec.yaml', json.encode(contents));

class _FileDescriptor extends Descriptor {
  final String contents;
  _FileDescriptor(String name, this.contents) : super(name);

  @override
  Future<void> create(Directory target) => target
      .childFile(name)
      .writeAsString(contents, encoding: utf8, mode: FileMode.write);
}

class _DirectoryDescriptor extends Descriptor {
  final List<Descriptor> contents;
  _DirectoryDescriptor(String name, List<Descriptor> contents)
      : contents = UnmodifiableListView(contents),
        super(name);

  @override
  Future<void> create(Directory target) async {
    final subfolder = target.childDirectory(name);
    await subfolder.create();
    await Future.wait(contents.map((d) => d.create(subfolder)));
  }
}
