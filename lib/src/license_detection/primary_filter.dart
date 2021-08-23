// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'license_detector.dart';

/// Filters [knownLicenses] and returns a list of licenses that could likely be a possible match for input.
///
/// A license might be a possible match from the list of [knownLicenses].
/// This function filters from the known licenses by weighing the
/// number of similar tokens through [tokenSimilarity] method and
/// returns a list of [License] which have a score above certain threshold.
@visibleForTesting
List<License> filter(
  Map<String, int> occurrences,
  List<License> knownLicenses,
) =>
    knownLicenses
        .where((license) =>
            tokenSimilarity(occurrences, license.tokenFrequency) >= 0.75)
        .toList();

/// Returns a measure for token similarity, between [input] and [knownLicense].
///
/// Token Similarity indicates if [License] is plausibly present as a
/// substring in [input]. This is determined by frequency tables over tokens given in [input] and
/// [knownLicense].

// Checks if the unknown text contains enough occurrences
// of tokens in a known license to qualify it as a possible match.
// If there are less number of a particular token in input as compared to known license
// there is a low probability that it might match and hence we do not count it, on the other
// hand if there are more or equal number we count that token
// and finally return the result (number of qualified unique tokens)/(total number of unique tokens in known license).
@visibleForTesting
double tokenSimilarity(Map<String, int> input, Map<String, int> knownLicense) {
  if (knownLicense.isEmpty) return 0;

  return knownLicense.entries
          .where((element) => (input[element.key] ?? 0) >= element.value)
          .length /
      knownLicense.length;
}
