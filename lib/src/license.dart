// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'license_detection/license_detector.dart' hide License, Range;
import 'model.dart';

const _licenseFileNames = ['LICENSE'];

Future<List<License>> detectLicenseInDir(String baseDir) async {
  final licenses = <License>[];
  for (final candidate in _licenseFileNames) {
    final file = File(p.join(baseDir, candidate));
    if (!file.existsSync()) continue;
    licenses.addAll(await detectLicenseInFile(file, relativePath: candidate));
  }
  // TODO: sort by confidence (the current order is per-file confidence).
  return licenses;
}

@visibleForTesting
Future<List<License>> detectLicenseInFile(File file,
    {required String relativePath}) async {
  final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  final licenses =
      await detectLicenseInContent(content, relativePath: relativePath);
  if (licenses.isEmpty) {
    return [License(path: relativePath, spdxIdentifier: LicenseNames.unknown)];
  }
  return licenses;
}

/// Returns the license(s) detected from the [SPDX-corpus][1].
///
/// [1]: https://spdx.org/licenses/
Future<List<License>> detectLicenseInContent(
  String content, {
  required String relativePath,
}) async {
  final licenseResult = await detectLicense(content, 0.95);

  if (licenseResult.unclaimedTokenPercentage > 0.5 ||
      licenseResult.longestUnclaimedTokenCount >= 50) {
    return <License>[];
  }

  return licenseResult.matches.map((e) {
    return License(
      path: relativePath,
      spdxIdentifier: e.identifier,
      range: Range(
        start: Position(
            offset: e.start.offset, line: e.start.line, column: e.start.column),
        end: Position(
            offset: e.end.offset, line: e.end.line, column: e.end.column),
      ),
    );
  }).toList();
}
