// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'license_detection/lcs.dart';
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
Future<List<License>> detectLicenseInFile(
  File file, {
  required String relativePath,
}) async {
  final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  final licenses = await detectLicenseInContent(
    content,
    relativePath: relativePath,
  );
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

  List<int> buildCoverages(LicenseMatch match) {
    final ops = calculateTokenEditOps(
      // ignore: invalid_use_of_visible_for_testing_member
      unknown: match.tokens,
      // ignore: invalid_use_of_visible_for_testing_member
      known: match.license.tokens,
    );

    return ops
        .whereType<MatchOp>()
        .expand(
          (op) => [
            op.pairs.first.unknown.span.start.offset,
            op.pairs.last.unknown.span.end.offset,
          ],
        )
        .toList();
  }

  return licenseResult.matches.map((e) {
    return License(
      path: relativePath,
      spdxIdentifier: e.identifier,
      range: Range(
        start: e.start.toPosition(),
        end: e.end.toPosition(),
        coverages: buildCoverages(e),
      ),
    );
  }).toList();
}

extension on SourceLocation {
  Position toPosition() => Position(offset: offset, line: line, column: column);
}
