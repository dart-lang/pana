@Timeout(Duration(minutes: 10))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pana/pana.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'env_utils.dart';
import 'golden_file.dart';

final _goldenDir = p.join('test', 'goldens', 'end2end');

final class _PackageToVerify {
  final String name;
  final String version;
  final bool skipDartdoc;

  const _PackageToVerify(this.name, this.version, {this.skipDartdoc = false});
}

const _packages = [
  // generic, cross-platform package
  _PackageToVerify('async', '2.13.0'),

  // cross-platform package with platform-specific code
  _PackageToVerify('http', '0.13.0', skipDartdoc: true),

  // js-only package
  _PackageToVerify('dnd', '2.0.1'),

  // flutter-only package
  _PackageToVerify('url_launcher', '6.3.1'),

  // single-platform Flutter plugin without Dart files or assets
  _PackageToVerify('nsd_android', '2.1.2', skipDartdoc: true),

  // binary-only package (without `platforms:` in pubspec)
  _PackageToVerify('onepub', '1.1.0'),

  // multi-level symlink
  _PackageToVerify('audio_service', '0.18.17', skipDartdoc: true),

  // downgrade failure
  _PackageToVerify('gg', '1.0.12', skipDartdoc: true),

  // mime_type 0.3.2 has no recognized LICENSE file
  _PackageToVerify('mime_type', '0.3.2', skipDartdoc: true),

  // no dart files, only assets (pre-2.12)
  _PackageToVerify('bulma_min', '0.7.4', skipDartdoc: true),

  // no dart files, only assets (post-2.12)
  _PackageToVerify('lints', '1.0.0', skipDartdoc: true),

  // debugging why platforms are not recognized
  // https://github.com/dart-lang/pana/issues/824
  _PackageToVerify('webdriver', '3.0.0', skipDartdoc: true),

  // uses dart:mirrors
  _PackageToVerify('steward', '0.3.1', skipDartdoc: true),

  // slightly old package
  _PackageToVerify('sdp_transform', '0.2.0', skipDartdoc: true),

  // really old package
  _PackageToVerify('skiplist', '0.1.0', skipDartdoc: true),

  // packages with bad content
  _PackageToVerify('_dummy_pkg', '1.0.0-null-safety.1'),
];

void main() {
  late final TestEnv testEnv;
  final results =
      <
        String,
        (Map<String, Object?>? actualMap, Object? error, StackTrace? st)
      >{};

  setUpAll(() async {
    final goldenDirLastModified = await _detectGoldenLastModified();
    testEnv = await TestEnv.createTemp(
      proxyPublishCutoff: goldenDirLastModified,
      dartdocVersion: 'any',
    );

    final pool = Pool(
      Platform.environment.containsKey('CI')
          ? 2
          : Platform.numberOfProcessors.clamp(1, _packages.length),
    );
    await Future.wait(
      _packages.map(
        (pkg) => pool.withResource(() async {
          final key = '${pkg.name}-${pkg.version}';
          try {
            final dartdocOutputDir = p.join(testEnv.tempDir.path, 'doc', key);
            await Directory(dartdocOutputDir).create(recursive: true);

            var summary = await testEnv.analyzer.inspectPackage(
              pkg.name,
              version: pkg.version,
              options: testEnv.inspectOptions(
                dartdocOutputDir: pkg.skipDartdoc ? null : dartdocOutputDir,
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
            // 3.10.1 -> 3.10.0
            final parsedSdkVersion = Version.parse(sdkVersion);
            final sdkZeroVersion = Version(
              parsedSdkVersion.major,
              parsedSdkVersion.minor,
              0,
            ).toString();

            // summary.toJson contains types which are not directly JSON-able
            // throwing it through `JSON.encode` does the trick
            final encoded = json.encode(summary);
            final updated = encoded
                .replaceAll(
                  '"sdkVersion":"$sdkVersion"',
                  '"sdkVersion":"{{sdk-version}}"',
                )
                .replaceAll(
                  'The current Dart SDK version is $sdkVersion.',
                  'The current Dart SDK version is {{sdk-version}}.',
                )
                .replaceAll(
                  'The current Dart SDK ($sdkVersion)',
                  'The current Dart SDK ({{sdk-version}})',
                )
                .replaceAll(
                  ' support current Dart version $sdkVersion.',
                  ' support current Dart version {{sdk-version}}.',
                )
                .replaceAll(
                  'sdk: \'^$sdkZeroVersion\'',
                  'sdk: \'^{{sdk-zero-version}}\'',
                )
                .replaceAll(
                  'the Dart version used by the latest stable Flutter ($flutterDartVersion)',
                  'the Dart version used by the latest stable Flutter ({{flutter-dart-version}})',
                )
                .replaceAll(
                  RegExp('that was published [0-9]+ days ago'),
                  'that was published N days ago',
                )
                .replaceAllMapped(RegExp(r'"coverages":\[(\d+(\,\d+)+)\]'), (
                  m,
                ) {
                  final parts = m.group(1)!.split(',');
                  final remaning = parts.indexed
                      .where((p) => p.$1 < 6 || p.$1 >= parts.length - 6)
                      .map((p) => p.$2)
                      .join(',');
                  return '"coverages":[$remaning]';
                });

            results[key] = (
              json.decode(updated) as Map<String, Object?>,
              null,
              null,
            );
          } catch (e, st) {
            results[key] = (null, e, st);
          }
        }),
      ),
    );
  });

  tearDownAll(() async {
    await testEnv.close();
  });

  for (final pkg in _packages) {
    final filename = '${pkg.name}-${pkg.version}.json';
    test('end2end: ${pkg.name} ${pkg.version}', () {
      final key = '${pkg.name}-${pkg.version}';
      final entry = results[key];
      if (entry == null) {
        fail('No result recorded for $key');
      }
      final (actualMap, error, st) = entry;
      if (error != null) {
        Error.throwWithStackTrace(error, st!);
      }
      if (actualMap == null) {
        fail('Null actualMap for $key');
      }

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

      final jsonContent =
          '${const JsonEncoder.withIndent('  ').convert(actualMap)}\n';

      // The tempdir creeps in to an error message.
      final jsonNoTempDir = jsonContent.replaceAll(
        RegExp(r'Error on line 5, column 1 of .*pubspec.yaml'),
        r'Error on line 5, column 1 of $TEMPDIR/pubspec.yaml',
      );

      final jsonGoldenFile = GoldenFile(p.join(_goldenDir, filename));
      jsonGoldenFile.writeContentIfNotExists(jsonNoTempDir);

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
        final reportGoldenFile = GoldenFile(
          p.join(_goldenDir, '${filename}_report.md'),
        );
        reportGoldenFile.writeContentIfNotExists(renderedSections);
        reportGoldenFile.expectContent(renderedSections);
      }

      // note: golden file expectations happen after content is already written
      jsonGoldenFile.expectContent(jsonNoTempDir);

      var summary = Summary.fromJson(actualMap);

      var roundTrip = json.decode(json.encode(summary));
      expect(roundTrip, actualMap);

      final tagsFileContent = File(
        'lib/src/tag/pana_tags.dart',
      ).readAsStringSync();

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
  }
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
