// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'package:pana/pana.dart';
import 'package:pana/src/version.dart';

const String goldenDir = 'test/end2end';

final _regenerateGoldens = false;

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

  void _verifyPackage(String fileName, String package, String version) {
    group('end2end: $package $version', () {
      Map<String, dynamic> actualMap;

      setUpAll(() async {
        var summary = await analyzer.inspectPackage(
          package,
          version: version,
          options: new InspectOptions(
            verbosity: Verbosity.verbose,
          ),
        );

        // summary.toJson contains types which are not directly JSON-able
        // throwing it through `JSON.encode` does the trick
        actualMap = json.decode(json.encode(summary)) as Map<String, dynamic>;
      });

      test('matches known good', () {
        final file = new File('$goldenDir/$fileName');
        if (_regenerateGoldens) {
          final content = new JsonEncoder.withIndent('  ').convert(actualMap);
          file.writeAsStringSync(content);
          fail('Set `_regenerateGoldens` to `false` to run tests.');
        }

        void removeDependencyDetails(Map map) {
          if (map.containsKey('pkgResolution') &&
              (map['pkgResolution'] as Map).containsKey('dependencies')) {
            final deps = (map['pkgResolution']['dependencies'] as List)
                .cast<Map<dynamic, dynamic>>();
            deps?.forEach((Map m) {
              m.remove('resolved');
              m.remove('available');
            });
          }
        }

        final Map content = json.decode(file.readAsStringSync());
        content['runtimeInfo']['panaVersion'] = matches(packageVersion);

        // TODO: allow future versions and remove this override
        content['runtimeInfo']['sdkVersion'] = isSemVer;

        // Reduce the time-invariability of the tests: resolved and available
        // versions may change over time or because of SDK version changes.
        removeDependencyDetails(actualMap);
        removeDependencyDetails(content);

        if (content.containsKey('suggestions')) {
          final suggestions =
              (content['suggestions'] as List).cast<Map<dynamic, dynamic>>();
          suggestions?.forEach((Map map) {
            // TODO: normalize paths in error reports and remove this override
            map['description'] = isNotEmpty;
          });
        }

        expect(actualMap, content);
      });

      test('Summary can round-trip', () {
        var summary = new Summary.fromJson(actualMap);

        var roundTrip = json.decode(json.encode(summary));
        expect(roundTrip, actualMap);
      });
    }, timeout: const Timeout.factor(2));
  }

  _verifyPackage('dartdoc-0.20.3.json', 'dartdoc', '0.20.3');
  _verifyPackage('http-0.11.3-17.json', 'http', '0.11.3+17');
  _verifyPackage('pub_server-0.1.4-2.json', 'pub_server', '0.1.4+2');
  _verifyPackage('skiplist-0.1.0.json', 'skiplist', '0.1.0');
  _verifyPackage('stream-2.0.1.json', 'stream', '2.0.1');
  _verifyPackage('fs_shim-0.7.1.json', 'fs_shim', '0.7.1');
}

Matcher isSemVer = predicate<String>((String versionString) {
  try {
    new Version.parse(versionString);
  } catch (e) {
    return false;
  }
  return true;
}, 'can be parsed as a version');
