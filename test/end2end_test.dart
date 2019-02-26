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
    await Directory(pubCacheDir).create();
    analyzer = await PackageAnalyzer.create(pubCacheDir: pubCacheDir);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  void _verifyPackage(String fileName, String package, String version,
      {bool hasStats = true}) {
    group('end2end: $package $version', () {
      Map<String, dynamic> actualMap;

      setUpAll(() async {
        var summary = await analyzer.inspectPackage(
          package,
          version: version,
          options: InspectOptions(
            verbosity: Verbosity.verbose,
          ),
        );

        // Fixed version strings to reduce changes on each upgrades.
        assert(summary.runtimeInfo.panaVersion == packageVersion);
        final sdkVersion = summary.runtimeInfo.sdkVersion;
        assert(sdkVersion != null);
        summary = summary.change(
            runtimeInfo: PanaRuntimeInfo(
          panaVersion: '{{pana-version}}',
          sdkVersion: '{{sdk-version}}',
          flutterVersions: {},
        ));

        // Fixed stats to reduce changes on each modification.
        if (hasStats) {
          assert(summary.stats != null);
          assert(summary.stats.analyzeProcessElapsed != null);
          assert(summary.stats.formatProcessElapsed != null);
          assert(summary.stats.resolveProcessElapsed != null);
          assert(summary.stats.totalElapsed != null);
          summary = summary.change(
            stats: Stats(
              analyzeProcessElapsed: 1234,
              formatProcessElapsed: 567,
              resolveProcessElapsed: 899,
              totalElapsed: 4567,
            ),
          );
        }

        // summary.toJson contains types which are not directly JSON-able
        // throwing it through `JSON.encode` does the trick
        final encoded = json.encode(summary);
        final updated = encoded
            .replaceAll(
                '"sdkVersion":"$sdkVersion"', '"sdkVersion":"{{sdk-version}}"')
            .replaceAll('The current Dart SDK version is $sdkVersion.',
                'The current Dart SDK version is {{sdk-version}}.');
        actualMap = json.decode(updated) as Map<String, dynamic>;
      });

      test('matches known good', () {
        final file = File('$goldenDir/$fileName');
        if (_regenerateGoldens) {
          final content = const JsonEncoder.withIndent('  ').convert(actualMap);
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

        final content = json.decode(file.readAsStringSync()) as Map;

        // Reduce the time-invariability of the tests: resolved and available
        // versions may change over time or because of SDK version changes.
        removeDependencyDetails(actualMap);
        removeDependencyDetails(content);

        expect(actualMap, content);
      });

      test('Summary can round-trip', () {
        var summary = Summary.fromJson(actualMap);

        var roundTrip = json.decode(json.encode(summary));
        expect(roundTrip, actualMap);
      });
    }, timeout: const Timeout.factor(2));
  }

  _verifyPackage(
      'angular_components-0.10.0.json', 'angular_components', '0.10.0');
  _verifyPackage('dartdoc-0.24.1.json', 'dartdoc', '0.24.1');
  _verifyPackage('http-0.11.3-17.json', 'http', '0.11.3+17');
  _verifyPackage('pub_server-0.1.4-2.json', 'pub_server', '0.1.4+2');
  _verifyPackage('skiplist-0.1.0.json', 'skiplist', '0.1.0');
  _verifyPackage('stream-2.0.1.json', 'stream', '2.0.1');
  _verifyPackage('fs_shim-0.7.1.json', 'fs_shim', '0.7.1');

  // packages with bad content
  _verifyPackage('syntax-0.2.0.json', 'syntax', '0.2.0', hasStats: false);
}

Matcher isSemVer = predicate<String>((String versionString) {
  try {
    Version.parse(versionString);
  } catch (e) {
    return false;
  }
  return true;
}, 'can be parsed as a version');
