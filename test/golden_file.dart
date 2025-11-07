// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

/// Will test [actual] against the contests of the file at [goldenFilePath].
///
/// If the file doesn't exist, the file is instead created containing [actual].
void expectMatchesGoldenFile(String actual, String goldenFilePath) {
  final goldenFile = GoldenFile(goldenFilePath);
  goldenFile.writeContentIfNotExists(actual);
  goldenFile.expectContent(actual);
}

/// Access to a file that contains the expected output of a process.
class GoldenFile {
  final String path;
  late final File _file;
  late final bool _didExists;
  late final String? _oldContent;

  GoldenFile(this.path) {
    _file = File(path);
    _didExists = false;
    //_file.existsSync();
    _oldContent = _didExists ? _file.readAsStringSync() : null;
  }

  void writeContentIfNotExists(String content) {
    if (_didExists) return;
    _file.createSync(recursive: true);
    _file.writeAsStringSync(content);
  }

  void expectContent(String actual) {
    if (_didExists) {
      expect(
        actual.replaceAll('\r\n', '\n'),
        equals(_oldContent!.replaceAll('\r\n', '\n')),
        reason:
            'goldenFilePath: "$path". '
            'To update the expectation delete this file and rerun the test.',
      );
    } else {
      fail('Golden file $path was recreated!');
    }
  }
}
