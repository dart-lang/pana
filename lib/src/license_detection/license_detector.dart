// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:pana/src/third_party/diff_match_patch/diff.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

part 'confidence.dart';
part 'crc32.dart';
part 'license.dart';
part 'primary_filter.dart';
part 'token_matcher.dart';
part 'tokenizer.dart';

// Load corpus licenses.
final _licenses = loadLicensesFromDirectories(_directories);

// WIP: Returns a list of detected licenses whose
// confidence score is above a certain threshold.
List<LicenseMatch> detectLicense(String text, double threshold) {
  final granularity = computeGranularity(threshold);

  final unknownLicense =
      LicenseWithNGrams.parse(License.parse('', text), granularity);

  final possibleLicenses = filter(unknownLicense.occurrences, _licenses)
      .map((e) => LicenseWithNGrams.parse(e, granularity));
  var result = <LicenseMatch>[];

  for (var license in possibleLicenses) {
    final matches = findPotentialMatches(
      unknownLicense,
      license,
      threshold,
      granularity,
    );

    for (var match in matches) {
      try {
        final hit = licenseMatch(unknownLicense, license, match, threshold);
        result.add(hit);
      } on LicensesMismatchException catch (e) {
        print(e.toString());
      }
    }
  }

  return List.unmodifiable(result);
}

/// Returns the minimum number of token runs that must match accordinf to
/// [threshold] to be able to consider it as match.
///
/// In a worst case scenario where the error is evenly
/// distributed (breaking the token runs most times), if we
/// consider 100 tokens and threshold 0.8, we'll have
/// 4 continuos matching tokens and a mismatch.
///
/// So this function returns the minimum number of tokens
/// or 1 (which is greater) to consider them as part
/// of known license text.
int computeGranularity(double threshold) {
  if (threshold == 1.0) {
    return 10; // avoid divide by 0
  }

  return max(1, threshold ~/ (1 - threshold));
}

const _directories = ['third_party/spdx/licenses'];
