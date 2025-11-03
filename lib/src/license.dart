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
    licenses.addAll(await detectLicenseInFile(file));
  }
  // TODO: sort by confidence (the current order is per-file confidence).
  return licenses;
}

@visibleForTesting
Future<List<License>> detectLicenseInFile(File file) async {
  final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  final licenses = await detectLicenseInContent(content);
  if (licenses.isEmpty) {
    return [License(spdxIdentifier: 'unknown')];
  }
  return licenses;
}

/// Returns the license(s) detected from the [SPDX-corpus][1].
///
/// [1]: https://spdx.org/licenses/
Future<List<License>> detectLicenseInContent(String content) async {
  final licenseResult = await detectLicense(content, 0.95);

  if (licenseResult.unclaimedTokenPercentage > 0.5 ||
      licenseResult.longestUnclaimedTokenCount >= 50) {
    return <License>[];
  }

  List<TextOp> buildCoverages(LicenseMatch match) {
    return match.tokenOps.map((op) {
      switch (op) {
        case MatchOp _:
          final start = op.pairs.first.unknown.span.start.offset;
          return TextOp(
            type: TextOpType.match,
            start: start,
            length: op.pairs.last.unknown.span.end.offset - start,
          );
        case InsertOp _:
          final start = op.tokens.first.span.start.offset;
          return TextOp(
            type: TextOpType.insert,
            start: start,
            length: op.tokens.last.span.end.offset - start,
          );
        case DeleteOp _:
          final deleteStart = op.tokens.first.span.start.offset;
          final deleteEnd = op.tokens.last.span.end.offset;
          final deleteLength = deleteEnd - deleteStart;

          // ignore: invalid_use_of_visible_for_testing_member
          final knownContent = match.license.content;
          final content = deleteLength < 64
              ? knownContent.substring(deleteStart, deleteEnd)
              : [
                  knownContent.substring(deleteStart, deleteStart + 24),
                  knownContent.substring(deleteEnd - 24, deleteEnd),
                ].join('[...]');

          return TextOp(
            type: TextOpType.delete,
            start: op.unknownPosition,
            length: deleteLength,
            content: content,
          );
      }
      throw UnimplementedError('Unknown op type: ${op.runtimeType}.');
    }).toList();
  }

  return licenseResult.matches.map((e) {
    return License(spdxIdentifier: e.identifier, operations: buildCoverages(e));
  }).toList();
}
