// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.license;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/license_detector.dart' hide License;
import 'package:path/path.dart' as p;

import 'maintenance.dart';
import 'model.dart';

Future<List<License>> detectLicenseInDir(String baseDir) async {
  final licenses = <License>[];
  for (final candidate in licenseFileNames) {
    final file = File(p.join(baseDir, candidate));
    if (!file.existsSync()) continue;
    licenses.addAll(await detectLicenseInFile(file, relativePath: candidate));
  }
  licenses.sort((a, b) => -a.confidence.compareTo(b.confidence));
  return licenses;
}

@visibleForTesting
Future<List<License>> detectLicenseInFile(File file,
    {required String relativePath}) async {
  final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  final licenses =
      await detectLicenseInContent(content, relativePath: relativePath);
  if (licenses.isEmpty) {
    return [
      License(
        path: relativePath,
        spdx: LicenseNames.unknown,
        confidence: 0.0,
        start: 0,
        end: content.length,
      )
    ];
  }
  return licenses;
}

/// Returns the license(s) detected from the [SPDX-corpus][1].
///
/// [1]: https://spdx.org/licenses/
Future<List<License>> detectLicenseInContent(
  String originalContent, {
  required String relativePath,
}) async {
  var content = originalContent;
  final licenseResult = await detectLicense(content, 0.95);

  if (licenseResult.unclaimedTokenPercentage > 0.5 ||
      licenseResult.longestUnclaimedTokenCount >= 50) {
    return <License>[];
  }

  return licenseResult.matches
      .map((e) => License(
            path: relativePath,
            spdx: e.identifier,
            confidence: e.confidence,
            start: e.start,
            end: e.end,
          ))
      .toList();
}
