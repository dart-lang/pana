// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/pana.dart';
import 'package:pana/src/package_context.dart';
import 'package:pana/src/report/create_report.dart';
import 'package:pana/src/screenshots.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package_descriptor.dart';

final _testImagesDir = p.join('test', 'testImages');

bool tryWebpTool() {
  try {
    Process.runSync('cwebp', []);
    Process.runSync('dwebp', []);
    Process.runSync('webpinfo', []);
    Process.runSync('gif2webp', []);
    Process.runSync('webpmux', []);
  } on ProcessException catch (_) {
    return false;
  }
  return true;
}

final hasWebpTools = tryWebpTool();

void main() {
  test('validates empty description', () async {
    final pkgDir = 'my_pkg';

    final s = Screenshot('', 'p');
    final declared = <Screenshot>[s];
    final r = await processAllScreenshots(declared, pkgDir);

    expect(r.length, 1);
    expect(r.first.processedScreenshot, isNull);
    expect(r.first.problems, isNotEmpty);
    expect(r.first.problems.first,
        contains('Screenshot `description` property is missing.'));
  });
  test('validates empty path', () async {
    final pkgDir = 'my_pkg';

    final s = Screenshot('d', '');
    final declared = <Screenshot>[s];
    final r = await processAllScreenshots(declared, pkgDir);

    expect(r.length, 1);
    expect(r.first.processedScreenshot, isNull);
    expect(r.first.problems, isNotEmpty);
    expect(r.first.problems.first,
        contains('Screenshot `path` property is missing.'));
  });
  test('validates long description', () async {
    final pkgDir = 'my_pkg';

    final longDescription =
        '012345678901234567890123456789012345678901234567890123456789012345678'
        '90123456789012345678901234567890123456789012345678901234567890123456'
        '789012345678901234567890123456789';
    final s = Screenshot(longDescription, 's');
    final declared = <Screenshot>[s];

    final r = await processAllScreenshots(declared, pkgDir);
    expect(r.length, 1);
    expect(r.first.processedScreenshot, isNull);
    expect(r.first.problems, isNotEmpty);
    expect(r.first.problems.first,
        contains('Screenshot `description` is too long.'));
  });

  test('validates image outside package', () async {
    final pkgDir = 'my_pkg';

    final s = Screenshot('description', '../s');
    final s1 = Screenshot('description', 's/../../s');
    final declared = <Screenshot>[s, s1];

    final r = await processAllScreenshots(declared, pkgDir);

    expect(r.length, 2);
    for (final result in r) {
      expect(result.processedScreenshot, isNull);
      expect(result.problems, isNotEmpty);
      expect(result.problems.first,
          contains('Screenshot file path should be within the package'));
    }
  });

  test('validates no existing file', () async {
    final pkgDir = 'my_pkg';

    final s = Screenshot('description', 's');
    final declared = <Screenshot>[s];

    final result = await processAllScreenshots(declared, pkgDir);

    expect(result.first.processedScreenshot, isNull);
    expect(result.first.problems, isNotEmpty);
    expect(result.first.problems.first,
        contains('No file found at specified screenshot `path`'));
  });

  test('success - process WebP, PNG and GIFs', () async {
    if (!hasWebpTools) return;
    final pkgDir = _testImagesDir;
    final s = Screenshot('description', 'static.webp');
    final s1 = Screenshot('description', 'animated.webp');
    final s2 = Screenshot('description', 'static.png');
    final s3 = Screenshot('description', 'static.gif');
    final s4 = Screenshot('description', 'animated.gif');
    final declared = <Screenshot>[s, s1, s2, s3, s4];

    final result = await processAllScreenshots(declared, pkgDir);

    expect(result.length, 5);
    for (final sr in result) {
      expect(sr.problems, isEmpty);
      expect(sr.processedScreenshot, isNotNull);
    }
  }, skip: !hasWebpTools);

  test('No more than 10 screenshots', () async {
    if (!hasWebpTools) return;
    final pkgDir = _testImagesDir;
    final s = Screenshot('description', 'static.webp');
    final s1 = Screenshot('description', 'animated.webp');
    final s2 = Screenshot('description', 'static.png');
    final s3 = Screenshot('description', 'static.gif');
    final s4 = Screenshot('description', 'animated.gif');
    final s5 = Screenshot('description', 'static.webp');
    final s6 = Screenshot('description', 'static.webp');
    final s7 = Screenshot('description', 'static.webp');
    final s8 = Screenshot('description', 'static.webp');
    final s9 = Screenshot('description', 'static.webp');
    final s10 = Screenshot('description', 'static.webp');

    final declared = <Screenshot>[s, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10];

    final result = await processAllScreenshots(declared, pkgDir);

    expect(result.length, 11);
    expect(result[10].problems, isNotEmpty);
    expect(result[10].processedScreenshot, isNull);
    expect(result[10].problems.first,
        contains('Not processed. pub.dev shows at most 10 screenshots'));
    for (var i = 0; i < 10; i++) {
      expect(result[i].processedScreenshot, isNotNull);
      expect(result[i].problems, isEmpty);
    }
  }, skip: !hasWebpTools);

  test('Failure: not an image', () async {
    if (!hasWebpTools) return;
    final pkgDir = _testImagesDir;
    final s = Screenshot('description', 'notAnImage.txt');
    final declared = <Screenshot>[s];

    final r = await processAllScreenshots(declared, pkgDir);
    expect(r.length, 1);
    expect(r.first.processedScreenshot, isNull);
    expect(r.first.problems.length, 4);
    expect(
        r.first.problems[0], contains('Tried interpreting screenshot as WebP'));
    expect(r.first.problems[1], contains('Converting screenshot with `cwebp '));
    expect(
        r.first.problems[2], contains('Tried interpreting screenshot as GIF'));
    expect(
        r.first.problems[3],
        contains(
            "Generating webp image for ${p.join(pkgDir, 'notAnImage.txt')} failed"));
  }, skip: !hasWebpTools);

  test('Failure: when webp tools are not installed', () async {
    if (hasWebpTools) return;
    final pkgDir = _testImagesDir;
    final s = Screenshot('description', 'static.webp');
    final declared = <Screenshot>[s];

    final r = await processAllScreenshots(declared, pkgDir);
    expect(r.length, 1);
    expect(r.first.processedScreenshot, isNull);
    expect(r.first.problems.length, greaterThan(0));
  }, skip: hasWebpTools);

  test('Report shows screenshot problems', () async {
    Map pubspecExtras = <String, List>{
      'screenshots': [
        {'description': '', 'path': 'doesNotExist'}
      ]
    };
    final descriptor =
        package('my_package', pubspecExtras: pubspecExtras, extraFiles: [
      d.dir('example', [
        d.file('README.md', 'Example'),
      ]),
    ]);
    await descriptor.create();

    final report = await createReport(PackageContext(
      sharedContext: SharedAnalysisContext(
        toolEnvironment: await ToolEnvironment.create(),
      ),
      packageDir: descriptor.io.path,
    ));

    final section =
        report.sections.firstWhere((s) => s.title == 'Provide documentation');
    expect(section.grantedPoints, 0);
    expect(
        section.summary,
        contains(
            'doesNotExist: Screenshot `description` property is missing.'));
    expect(
        section.summary,
        contains(
            'doesNotExist: No file found at specified screenshot `path` doesNotExist'));
  });

  test('Successful report', () async {
    if (!hasWebpTools) return;
    Map pubspecExtras = <String, List>{
      'screenshots': [
        {'description': 'description', 'path': 'static.webp'}
      ]
    };
    final descriptor =
        package('my_package', pubspecExtras: pubspecExtras, extraFiles: [
      d.dir('example', [
        d.file('example.md', 'Example'),
      ]),
      d.file('static.webp',
          File(p.join(_testImagesDir, 'static.webp')).readAsBytesSync())
    ]);
    await descriptor.create();

    final report = await createReport(PackageContext(
      sharedContext: SharedAnalysisContext(
        toolEnvironment: await ToolEnvironment.create(),
      ),
      packageDir: descriptor.io.path,
    ));

    final section =
        report.sections.firstWhere((s) => s.title == 'Provide documentation');
    expect(section.grantedPoints, 10);
    expect(
        section.summary, isNot(contains('Issues with declared screenshots')));
  }, skip: !hasWebpTools);
}
