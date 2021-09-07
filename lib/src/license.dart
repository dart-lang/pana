// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.license;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pana/src/license_detection/license_detector.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'download_utils.dart';
import 'maintenance.dart';
import 'model.dart';

Future<LicenseFile?> detectLicenseInDir(String baseDir) async {
  for (final candidate in licenseFileNames) {
    final file = File(p.join(baseDir, candidate));
    if (!file.existsSync()) continue;
    return detectLicenseInFile(file, relativePath: candidate);
  }
  return null;
}

Future<String?> getLicenseUrl(
    UrlChecker urlChecker, String? baseUrl, LicenseFile? license) async {
  if (baseUrl == null || baseUrl.isEmpty) {
    return null;
  }
  if (license == null || license.path.isEmpty) {
    return null;
  }
  final url = getRepositoryUrl(baseUrl, license.path);
  if (url == null) {
    return null;
  }
  final status = await urlChecker.checkStatus(url);
  return status.exists ? url : null;
}

@visibleForTesting
Future<LicenseFile> detectLicenseInFile(File file,
    {required String relativePath}) async {
  final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  var license = detectLicenseInContent(content, relativePath: relativePath);
  return license ?? LicenseFile(relativePath, LicenseNames.unknown);
}

/// Returns an instance of [LicenseFile] if [originalContent] has contains a license(s)
/// present in the [SPDX-corpus][1].
///
/// [1]: https://spdx.org/licenses/
LicenseFile? detectLicenseInContent(String originalContent,
    {required String relativePath}) {
  var content = originalContent;
  final licenseResult = detectLicense(content, 0.95);

  if (licenseResult.matches.isNotEmpty &&
      licenseResult.unclaimedTokenPercentage <= 0.5 &&
      licenseResult.longestUnclaimedTokenCount < 50) {
    return LicenseFile(
      relativePath,
      licenseResult.matches.first.identifier,
    );
  }

  return null;
}
