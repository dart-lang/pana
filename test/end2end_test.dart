// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/pana.dart';
import 'package:pana/src/create_report.dart';
import 'package:pana/src/version.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'golden_file.dart';

final _goldenDir = p.join('test', 'goldens', 'end2end');

void main() {
  String tempDir;
  PackageAnalyzer analyzer;

  setUpAll(() async {
    isRunningEnd2EndTest = true;
    tempDir = Directory.systemTemp
        .createTempSync('pana-test')
        .resolveSymbolicLinksSync();
    final pubCacheDir = p.join(tempDir, 'pub-cache');
    Directory(pubCacheDir).createSync();
    analyzer = await PackageAnalyzer.create(pubCacheDir: pubCacheDir);
  });

  tearDownAll(() async {
    Directory(tempDir).deleteSync(recursive: true);
  });

  void _verifyPackage(String package, String version) {
    final filename = '$package-$version.json';
    group('end2end: $package $version', () {
      Map<String, dynamic> actualMap;

      setUpAll(() async {
        var summary = await analyzer.inspectPackage(
          package,
          version: version,
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

        // Reduce the time-invariability of the tests: resolved and available
        // versions may change over time or because of SDK version changes.
        removeDependencyDetails(actualMap);

        final json = const JsonEncoder.withIndent('  ').convert(actualMap);

        // The tempdir creeps in to an error message.
        final jsonNoTempDir = json.replaceAll(
            RegExp(r'Error on line 5, column 1 of .*pubspec.yaml'),
            r'Error on line 5, column 1 of $TEMPDIR/pubspec.yaml');

        expectMatchesGoldenFile(jsonNoTempDir, p.join(_goldenDir, filename));
      });

      test('Report matches known good', () {
        final jsonReport = actualMap['report'] as Map<String, dynamic>;
        if (jsonReport != null) {
          final report = Report.fromJson(jsonReport);
          final renderedSections = report.sections
              .map(
                (s) =>
                    '## ${s.grantedPoints}/${s.maxPoints} ${s.title}\n\n${s.summary}',
              )
              .join('\n\n');
          // For readability we output the report in its own file.
          expectMatchesGoldenFile(
              renderedSections, p.join(_goldenDir, '${filename}_report.md'));
        }
      });

      test('Summary can round-trip', () {
        var summary = Summary.fromJson(actualMap);

        var roundTrip = json.decode(json.encode(summary));
        expect(roundTrip, actualMap);
      });
    }, timeout: const Timeout.factor(2));
  }

  _verifyPackage('angular_components', '0.10.0');
  _verifyPackage('http', '0.11.3+17');
  _verifyPackage('pub_server', '0.1.4+2');
  _verifyPackage('skiplist', '0.1.0');
  _verifyPackage('stream', '2.0.1');
  _verifyPackage('fs_shim', '0.7.1');
  // mime_type 0.3.2 has no recognized LICENSE file
  _verifyPackage('mime_type', '0.3.2');
  // bulma_min 0.7.4 has no dart files, only assets
  _verifyPackage('bulma_min', '0.7.4');

  // packages with bad content
  _verifyPackage('syntax', '0.2.0');
  _verifyPackage('_dummy_pkg', '1.0.0-null-safety.0');
  _verifyPackage('_dummy_pkg', '1.0.0-null-safety.1');
}

Matcher isSemVer = predicate<String>((String versionString) {
  try {
    Version.parse(versionString);
  } catch (e) {
    return false;
  }
  return true;
}, 'can be parsed as a version');
