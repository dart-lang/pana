// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:pana/src/license_detection/confidence.dart';
import 'package:pana/src/license_detection/license.dart';
import 'package:pana/src/license_detection/primary_filter.dart';
import 'package:pana/src/license_detection/token_matcher.dart';

// Load corpus licenses.
final _licenses = loadLicensesFromDirectories(_directories);

// WIP: Returns a list of detected licenses whose
// confidence score is above a certain threshold.
List<LicenseMatch> detectLicense(String text, double threshold) {
  final granularity = computeGranularity(threshold);
  final unknownLicense =
      PossibleLicense.parse(License.parse('', text), granularity);
  final possibleLicenses =
      filter(unknownLicense.license.occurrences, _licenses, granularity);
  var result = <LicenseMatch>[];

  for (var license in possibleLicenses) {
    final matches = findPotentialMatches(
      unknownLicense,
      license,
      threshold,
      granularity,
    );

    for (var match in matches) {
      final licenseMatch =
          confidenceMatch(unknownLicense, license, match, threshold);

      if (licenseMatch != null) {
        result.add(licenseMatch);
      }
    }
  }

  return List.unmodifiable(result);
}

int computeGranularity(double threshold) {
  if (threshold == 1.0) {
    return 10; // avoid divide by 0
  }

  return max(1, threshold ~/ (1 - threshold));
}

const _directories = ['third_party/spdx/licenses'];

void main() {
  final matches = detectLicense(_test, 0.8);

  for (var match in matches) {
    print(
        'License: ${match.license.identifier} Confidence: ${match.confidence}');
  }
}

const _test = '''
* @license
 * Copyright(c) 2010-2013 TJ Holowaychuk <tj@vision-media.ca>
 * Copyright(c) 2013-2017 Denis Bardadym <bardadymchik@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
''';
