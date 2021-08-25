// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
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

class Result {
  /// Licenses detected in the input text.
  ///
  /// The list is empty if no licenses are detected.
  final List<LicenseMatch> matches;

  /// Percentage of tokens in the unknown license that were not claimed in any of the license matches.
  final double unclaimedTokenPercentage;

  /// The count of the longest sequence of token in the input
  /// text that was not a part of any detected license.
  final int longestUnclaimedTokenCount;

  Result(this.matches, this.unclaimedTokenPercentage,
      this.longestUnclaimedTokenCount);
}

/// Returns an instance of [Result] for every license in the corpus detected
/// in the unknown text with a confidence greater than [threshold].
Result detectLicense(String text, double threshold) {
  final granularity = computeGranularity(threshold);

  final unknownLicense = LicenseWithNGrams.parse(
      License.parse(identifier: '', content: text), granularity);

  final possibleLicenses = filter(unknownLicense.tokenFrequency, _licenses)
      .map((e) => LicenseWithNGrams.parse(e, granularity));
  var result = <LicenseMatch>[];

  for (var license in possibleLicenses) {
    final matches = findPotentialMatches(
      unknownLicense,
      license,
      threshold,
    );

    for (var match in matches) {
      try {
        final hit = licenseMatch(unknownLicense, license, match, threshold);
        result.add(hit);
      } on LicenseMismatchException catch (_) {
        // print(e.toString());
      }
    }
  }

  result = removeDuplicates(result);
  result.sort(sortOnConfidence);
  result = removeOverLappingMatches(result);
  final unclaimedPercentage =
      unclaimedTokenPercentage(result, unknownLicense.tokens.length);
  final longestUnclaimedTokenCount = findLongestUnclaimedTokenRange(result);
  return Result(List.unmodifiable(result), unclaimedPercentage,
      longestUnclaimedTokenCount);
}

/// Returns the minimum number of token runs that must match according to
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
@visibleForTesting
int computeGranularity(double threshold) {
  if (threshold > 0.9) {
    return 10; // avoid divide by 0
  }

  return max(1, threshold ~/ (1 - threshold));
}

/// For [LicenseMatch] in [matches] having the same `spdx-identifier` the one with highest confidence
/// is considered and rest are discared.
@visibleForTesting
List<LicenseMatch> removeDuplicates(List<LicenseMatch> matches) {
  var identifierToLicense = <String, LicenseMatch>{};

  for (var match in matches) {
    if (identifierToLicense.containsKey(match.identifier)) {
      var prevMatch = identifierToLicense[match.identifier];
      // As both the licenses are same consider tha max of tokens claimed among these two.

      prevMatch = prevMatch!.confidence > match.confidence ? prevMatch : match;
      prevMatch = prevMatch.updateTokenIndex(
        min(prevMatch.tokenRange.start, match.tokenRange.start),
        max(prevMatch.tokenRange.end, match.tokenRange.end),
      );

      identifierToLicense[match.identifier] = prevMatch;
      continue;
    }

    identifierToLicense[match.identifier] = match;
  }

  return identifierToLicense.values.toList();
}

/// Custom comparator to the sort the licenses based on decreasing order of confidence.
///
/// Incase the confidence detected is same for the matches, ratio of tokens claimed
/// in the unkown text to the number of tokens present in the known license text
/// is considered
@visibleForTesting
int sortOnConfidence(LicenseMatch matchA, LicenseMatch matchB) {
  if (matchA.confidence > matchB.confidence) {
    return -1;
  }

  if (matchA.confidence < matchB.confidence) {
    return 1;
  }

  final matchATokensPercent =
      matchA.tokensClaimed / matchA.license.tokens.length;
  final matchBTokensPercent =
      matchB.tokensClaimed / matchB.license.tokens.length;

  return (matchATokensPercent > matchBTokensPercent) ? -1 : 1;
}

/// Fliters out licenses having overlapping ranges giving preferences to a match with higher token density.
///
/// Token density is the product of number of tokens claimed in the range and
/// confidence score of the match. Incase of exact match we retain both
/// the matches so that the user can resolve them.
@visibleForTesting
List<LicenseMatch> removeOverLappingMatches(List<LicenseMatch> matches) {
  var retain = List.filled(matches.length, false);
  var retainedmatches = <LicenseMatch>[];

  // We consider token density to retain matches of larger licenses
  // having lesser confidence when compared to a smaller license
  // haing a  perfect match.
  for (var i = 0; i < matches.length; i++) {
    var keep = true;
    final matchA = matches[i];
    final rangeA = Range(matchA.start, matchA.end);

    var proposals = <int, bool>{};
    for (var j = 0; j < matches.length; j++) {
      if (j == i) {
        break;
      }
      final matchB = matches[j];
      final rangeB = Range(matchB.start, matchB.end);
      // Check if matchA is larger license containing an insatnce of
      // smaller license within it and decide to whether retain it
      // or not by comapring their token densities. Example NPL
      // contains MPL.
      if (rangeA.contains(rangeB) && retain[j]) {
        final aConf = matchA.tokensClaimed * matchA.confidence;
        final bConf = matchB.tokensClaimed * matchB.confidence;

        // Retain both the licenses incase of a exact match,
        // so that it can be resolved by the user.
        if (aConf > bConf) {
          proposals[j] = true;
        } else if (bConf > aConf) {
          keep = false;
        }
      } else if (rangeA.overlapsWith(rangeB)) {
        keep = false;
      }
    }

    if (keep) {
      retain[i] = true;
      proposals.forEach((key, value) {
        retain[key] = value;
      });
    }
  }

  for (var i = 0; i < matches.length; i++) {
    if (retain[i]) {
      retainedmatches.add(matches[i]);
    }
  }

  return retainedmatches;
}


double unclaimedTokenPercentage(
    List<LicenseMatch> matches, int unknownTokensCount) {
  var claimedTokenCount = 0;

  for (var match in matches) {
    claimedTokenCount += match.tokensClaimed;
  }

  return max(0, (unknownTokensCount - claimedTokenCount) / unknownTokensCount);
}

const _directories = ['third_party/spdx/licenses'];

int findLongestUnclaimedTokenRange(List<LicenseMatch> matches) {
  var ranges = <Range>[];

  for (var match in matches) {
    ranges.add(Range(match.tokenRange.start, match.tokenRange.end));
  }

  ranges.sort(sortRangeOnStartValue);
  var maxTokenSequence = 0;

  for (var i = 1; i < ranges.length; i++) {
    maxTokenSequence =
        max(ranges[i].start - ranges[i - 1].end, maxTokenSequence);
  }

  return maxTokenSequence;
}

int sortRangeOnStartValue(Range a, Range b) => a.start - b.start;
