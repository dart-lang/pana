// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pana/pana.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';

import 'golden_file.dart';

final _goldenDir = p.join('test', 'goldens', 'end2end');
final _pubDevUri = Uri.parse('https://pub.dartlang.org/');

void main() {
  void verifyPackage(
    String package,
    String version, {
    bool skipDartdoc = false,
  }) {
    final filename = '$package-$version.json';
    group('end2end: $package $version', () {
      late String tempDir;
      late PackageAnalyzer analyzer;
      http.Client? httpClient;
      late HttpServer httpServer;
      late final Map<String, Object?> actualMap;

      setUpAll(() async {
        tempDir = Directory.systemTemp
            .createTempSync('pana-test')
            .resolveSymbolicLinksSync();
        final pubCacheDir = p.join(tempDir, 'pub-cache');
        final panaCacheDir = p.join(tempDir, 'pana-cache');
        final dartConfigDir = p.join(tempDir, 'config', 'dart');
        final flutterConfigDir = p.join(tempDir, 'config', 'flutter');
        final goldenDirLastModified = await _detectGoldenLastModified();
        Directory(pubCacheDir).createSync();
        Directory(panaCacheDir).createSync();
        Directory(dartConfigDir).createSync(recursive: true);
        Directory(flutterConfigDir).createSync(recursive: true);
        httpClient = http.Client();
        httpServer = await _startLocalProxy(
          httpClient: httpClient,
          blockPublishAfter: goldenDirLastModified,
        );
        analyzer = PackageAnalyzer(await ToolEnvironment.create(
          dartSdkConfig: SdkConfig(configHomePath: dartConfigDir),
          flutterSdkConfig: SdkConfig(configHomePath: flutterConfigDir),
          pubCacheDir: pubCacheDir,
          pubHostedUrl: 'http://127.0.0.1:${httpServer.port}',
          // TODO: revert to 'any' after SDK 3.6 is out
          dartdocVersion: '^8.3.0',
        ));

        final dartdocOutputDir = p.join(tempDir, 'doc', '$package-$version');
        await Directory(dartdocOutputDir).create(recursive: true);

        var summary = await analyzer.inspectPackage(
          package,
          version: version,
          options: InspectOptions(
            pubHostedUrl: 'http://127.0.0.1:${httpServer.port}',
            panaCacheDir: panaCacheDir,
            dartdocOutputDir: skipDartdoc ? null : dartdocOutputDir,
          ),
        );

        // Fixed version strings to reduce changes on each upgrades.
        assert(summary.runtimeInfo.panaVersion == packageVersion);
        final sdkVersion = summary.runtimeInfo.sdkVersion;
        final flutterDartVersion =
            summary.runtimeInfo.flutterInternalDartSdkVersion;
        summary = summary.change(
          createdAt: DateTime.utc(2022, 11, 23, 11, 09),
          runtimeInfo: PanaRuntimeInfo(
            panaVersion: '{{pana-version}}',
            sdkVersion: '{{sdk-version}}',
            flutterVersions: {},
          ),
        );

        // summary.toJson contains types which are not directly JSON-able
        // throwing it through `JSON.encode` does the trick
        final encoded = json.encode(summary);
        final updated = encoded
            .replaceAll(
                '"sdkVersion":"$sdkVersion"', '"sdkVersion":"{{sdk-version}}"')
            .replaceAll('The current Dart SDK version is $sdkVersion.',
                'The current Dart SDK version is {{sdk-version}}.')
            .replaceAll(' support current Dart version $sdkVersion.',
                ' support current Dart version {{sdk-version}}.')
            .replaceAll(
                'the Dart version used by the latest stable Flutter ($flutterDartVersion)',
                'the Dart version used by the latest stable Flutter ({{flutter-dart-version}})')
            .replaceAll(RegExp('that was published [0-9]+ days ago'),
                'that was published N days ago');
        actualMap = json.decode(updated) as Map<String, Object?>;
      });

      tearDownAll(() async {
        await httpServer.close(force: true);
        httpClient!.close();
        Directory(tempDir).deleteSync(recursive: true);
      });

      test('matches known good', () {
        void removeDependencyDetails(Map<String, dynamic> map) {
          if (map.containsKey('pkgResolution') &&
              (map['pkgResolution'] as Map).containsKey('dependencies')) {
            final deps = (map['pkgResolution']['dependencies'] as List)
                .cast<Map<dynamic, dynamic>>();
            for (final m in deps) {
              m.remove('resolved');
              m.remove('available');
            }
          }
        }

        // Reduce the time-invariability of the tests: resolved and available
        // versions may change over time or because of SDK version changes.
        removeDependencyDetails(actualMap);

        final json =
            '${const JsonEncoder.withIndent('  ').convert(actualMap)}\n';

        // The tempdir creeps in to an error message.
        final jsonNoTempDir = json.replaceAll(
            RegExp(r'Error on line 5, column 1 of .*pubspec.yaml'),
            r'Error on line 5, column 1 of $TEMPDIR/pubspec.yaml');

        expectMatchesGoldenFile(jsonNoTempDir, p.join(_goldenDir, filename));
      });

      test('Report matches known good', () {
        final jsonReport = actualMap['report'] as Map<String, Object?>?;
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

      test('Summary tags check', () {
        final tagsFileContent =
            File('lib/src/tag/pana_tags.dart').readAsStringSync();
        final summary = Summary.fromJson(actualMap);
        final tags = summary.tags;
        if (tags != null) {
          for (final tag in tags) {
            // tags that are in the `pana_tags.dart` file are skipped
            if (tagsFileContent.contains("'$tag'")) {
              continue;
            }
            if (tag.startsWith('license:')) {
              // SPDX license tags are skipped
              continue;
            }
            if (tag.startsWith('topic:')) {
              // topic tags are skipped
              continue;
            }
            fail('Unexpected tag in the result: "$tag"');
          }
        }
      });
    }, timeout: const Timeout.factor(2));
  }

  // generic, cross-platform package
  verifyPackage('async', '2.11.0');

  // cross-platform package with platform-specific code
  verifyPackage('http', '0.13.0', skipDartdoc: true);

  // js-only package
  verifyPackage('dnd', '2.0.1');

  // flutter-only package
  verifyPackage('url_launcher', '6.3.1');

  // single-platform Flutter plugin without Dart files or assets
  verifyPackage('nsd_android', '2.1.2', skipDartdoc: true);

  // binary-only package (without `platforms:` in pubspec)
  verifyPackage('onepub', '1.1.0');

  // multi-level symlink
  verifyPackage('audio_service', '0.18.17', skipDartdoc: true);

  // downgrade failure
  verifyPackage('gg', '1.0.12', skipDartdoc: true);

  // mime_type 0.3.2 has no recognized LICENSE file
  verifyPackage('mime_type', '0.3.2', skipDartdoc: true);

  // no dart files, only assets (pre-2.12)
  verifyPackage('bulma_min', '0.7.4', skipDartdoc: true);

  // no dart files, only assets (post-2.12)
  verifyPackage('lints', '1.0.0', skipDartdoc: true);

  // debugging why platforms are not recognized
  // https://github.com/dart-lang/pana/issues/824
  verifyPackage('webdriver', '3.0.0', skipDartdoc: true);

  // uses dart:mirrors
  verifyPackage('steward', '0.3.1', skipDartdoc: true);

  // slightly old package
  verifyPackage('sdp_transform', '0.2.0', skipDartdoc: true);

  // really old package
  verifyPackage('skiplist', '0.1.0', skipDartdoc: true);

  // packages with bad content
  verifyPackage('_dummy_pkg', '1.0.0-null-safety.1');
}

Future<DateTime> _detectGoldenLastModified() async {
  final timestampFile = File(p.join(_goldenDir, '__timestamp.txt'));
  await timestampFile.parent.create(recursive: true);
  if (timestampFile.existsSync()) {
    final content = await timestampFile.readAsString();
    return DateTime.parse(content.trim());
  } else {
    final now = DateTime.now().toUtc();
    await timestampFile.writeAsString('${now.toIso8601String()}\n');
    return now;
  }
}

Future<HttpServer> _startLocalProxy({
  required http.Client? httpClient,
  required DateTime blockPublishAfter,
}) {
  return serve(
    (shelf.Request rq) async {
      final pubDevUri = _pubDevUri.replace(path: rq.requestedUri.path);
      final rs = await httpClient!.get(pubDevUri);
      final segments = rq.requestedUri.pathSegments;
      if (rs.statusCode == 200 &&
          segments.length == 3 &&
          segments[0] == 'api' &&
          segments[1] == 'packages') {
        final content = json.decode(rs.body) as Map<String, dynamic>;
        final versions =
            (content['versions'] as List).cast<Map<String, dynamic>>();
        versions.removeWhere((item) {
          final published = DateTime.parse(item['published'] as String);
          return published.isAfter(blockPublishAfter);
        });
        return shelf.Response.ok(json.encode(content));
      }
      return shelf.Response(
        rs.statusCode,
        body: gzip.encode(rs.bodyBytes),
        headers: {
          'content-encoding': 'gzip',
        },
      );
    },
    '127.0.0.1',
    0,
  );
}
