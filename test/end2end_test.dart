// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/pana.dart';
import 'package:test/test.dart';

import 'end2end/pub_server_data.dart' as pub_server_data;

void main() {
  group('PackageAnalyzer', () {
    Directory tempDir;
    PackageAnalyzer analyzer;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('pana-test');
      var pubCacheDir = await tempDir.resolveSymbolicLinks();
      analyzer = new PackageAnalyzer(pubCacheDir: pubCacheDir);
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    group('pub_server 0.1.1+3', () {
      Map actualMap;

      setUpAll(() async {
        var summary = await analyzer.inspectPackage(
          'pub_server',
          version: '0.1.1+3',
          keepTransitiveLibs: true,
        );

        actualMap = JSON.decode(JSON.encode(summary));
      });

      test('matches known good', () {
        expect(actualMap, pub_server_data.data);
      });

      test('Summary can round-trip', () {
        var summary = new Summary.fromJson(actualMap);

        var roundTrip = JSON.decode(JSON.encode(summary));
        expect(roundTrip, actualMap);
      });
    }, timeout: const Timeout.factor(2));
  });
}
