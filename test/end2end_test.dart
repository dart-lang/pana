// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/pana.dart';
import 'package:test/test.dart';

import 'end2end/http_data.dart' as http_data;
import 'end2end/pub_server_data.dart' as pub_server_data;
import 'end2end/shared.dart';
import 'end2end/skiplist_data.dart' as skiplist_data;
import 'end2end/stream_broken_data.dart' as stream_broken_data;

void main() {
  Directory tempDir;
  String rootPath;
  PackageAnalyzer analyzer;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pana-test');
    rootPath = await tempDir.resolveSymbolicLinks();
    final pubCacheDir = '$rootPath/pub-cache';
    await new Directory(pubCacheDir).create();
    analyzer = await PackageAnalyzer.create(pubCacheDir: pubCacheDir);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  void _verifyPackage(E2EData data) {
    group('${data.name} ${data.version}', () {
      Map actualMap;

      setUpAll(() async {
        var summary = await analyzer.inspectPackage(
          data.name,
          version: data.version,
          options: new InspectOptions(
            verbosity: Verbosity.verbose,
            dartdocOutputDir: '$rootPath/dartdoc',
          ),
        );

        // summary.toJson contains types which are not directly JSON-able
        // throwing it through `JSON.encode` does the trick
        actualMap = json.decode(json.encode(summary));
      });

      test('matches known good', () {
        expect(actualMap, data.data);
      });

      test('Summary can round-trip', () {
        var summary = new Summary.fromJson(actualMap);

        var roundTrip = json.decode(json.encode(summary));
        expect(roundTrip, actualMap);
      });
    }, timeout: const Timeout.factor(2));
  }

  _verifyPackage(pub_server_data.data);
  _verifyPackage(http_data.data);
  _verifyPackage(skiplist_data.data);
  _verifyPackage(stream_broken_data.data);
}
