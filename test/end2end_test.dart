// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pana/pana.dart';
import 'package:pana/src/version.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';

import 'golden_file.dart';

final _goldenDir = p.join('test', 'goldens', 'end2end');
final _pubDevUri = Uri.parse('https://pub.dartlang.org/');

void main() {
  late String tempDir;
  late PackageAnalyzer analyzer;
  http.Client? httpClient;
  late HttpServer httpServer;

  setUpAll(() async {
    tempDir = Directory.systemTemp
        .createTempSync('pana-test')
        .resolveSymbolicLinksSync();
    final pubCacheDir = p.join(tempDir, 'pub-cache');
    final goldenDirLastModified = await _detectGoldenLastModified();
    Directory(pubCacheDir).createSync();
    httpClient = http.Client();
    httpServer = await _startLocalProxy(
      httpClient: httpClient,
      blockPublishAfter: goldenDirLastModified,
    );
    analyzer = await PackageAnalyzer.create(
        pubCacheDir: pubCacheDir,
        pubHostedUrl: 'http://127.0.0.1:${httpServer.port}');
  });

  tearDownAll(() async {
    await httpServer.close(force: true);
    httpClient!.close();
    Directory(tempDir).deleteSync(recursive: true);
  });

  void _verifyPackage(String package, String version) {
    final filename = '$package-$version.json';
    group('end2end: $package $version', () {
      Map<String, dynamic>? actualMap;

      setUpAll(() async {
        var summary = await analyzer.inspectPackage(
          package,
          version: version,
          options: InspectOptions(
            pubHostedUrl: 'http://127.0.0.1:${httpServer.port}',
          ),
        );

        // Fixed version strings to reduce changes on each upgrades.
        assert(summary.runtimeInfo.panaVersion == packageVersion);
        final sdkVersion = summary.runtimeInfo.sdkVersion;
        final flutterDartVersion =
            summary.runtimeInfo.flutterInternalDartSdkVersion;
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
                'The current Dart SDK version is {{sdk-version}}.')
            .replaceAll(' support current Dart version $sdkVersion.',
                ' support current Dart version {{sdk-version}}.')
            .replaceAll(
                'the Dart version used by the latest stable Flutter ($flutterDartVersion)',
                'the Dart version used by the latest stable Flutter ({{flutter-dart-version}})')
            .replaceAll(RegExp('that was published [0-9]+ days ago'),
                'that was published N days ago');
        actualMap = json.decode(updated) as Map<String, dynamic>?;
      });

      test('matches known good', () {
        void removeDependencyDetails(Map map) {
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
        removeDependencyDetails(actualMap!);

        final json = const JsonEncoder.withIndent('  ').convert(actualMap);

        // The tempdir creeps in to an error message.
        final jsonNoTempDir = json.replaceAll(
            RegExp(r'Error on line 5, column 1 of .*pubspec.yaml'),
            r'Error on line 5, column 1 of $TEMPDIR/pubspec.yaml');

        expectMatchesGoldenFile(jsonNoTempDir, p.join(_goldenDir, filename));
      });

      test('Report matches known good', () {
        final jsonReport = actualMap!['report'] as Map<String, dynamic>?;
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
        var summary = Summary.fromJson(actualMap!);

        var roundTrip = json.decode(json.encode(summary));
        expect(roundTrip, actualMap);
      });
    }, timeout: const Timeout.factor(2));
  }

  // generic, cross-platform package
  _verifyPackage('async', '2.5.0');

  // cross-platform package with platform-specific code
  _verifyPackage('http', '0.13.0');

  // js-only package
  _verifyPackage('dnd', '2.0.0');

  // flutter-only package
  _verifyPackage('url_launcher', '6.0.3');

  // multi-level symlink
  _verifyPackage('audio_service', '0.17.0');

  // mime_type 0.3.2 has no recognized LICENSE file
  _verifyPackage('mime_type', '0.3.2');

  // no dart files, only assets (pre-2.12)
  _verifyPackage('bulma_min', '0.7.4');

  // no dart files, only assets (post-2.12)
  _verifyPackage('lints', '1.0.0');

  // debugging why platforms are not recognized
  // https://github.com/dart-lang/pana/issues/824
  _verifyPackage('webdriver', '3.0.0');

  // slightly old package
  _verifyPackage('sdp_transform', '0.2.0');

  // really old package
  _verifyPackage('skiplist', '0.1.0');

  // packages with bad content
  _verifyPackage('_dummy_pkg', '1.0.0-null-safety.1');
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
