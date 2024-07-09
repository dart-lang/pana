// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../third_party/diff_match_patch/diff.dart';

part 'confidence.dart';
part 'crc32.dart';
part 'license.dart';
part 'primary_filter.dart';
part 'token_matcher.dart';
part 'tokenizer.dart';

const _defaultSpdxLicenseDir = 'lib/src/third_party/spdx/licenses';

// Load corpus licenses.
List<License>? _cachedLicenses;
Future<List<License>> _getDefaultLicenses() async {
  if (_cachedLicenses == null) {
    final uri = await Isolate.resolvePackageUri(Uri.parse(
        _defaultSpdxLicenseDir.replaceFirst('lib/', 'package:pana/')));
    _cachedLicenses =
        loadLicensesFromDirectories([Directory.fromUri(uri!).path]);
  }
  return _cachedLicenses!;
}

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
Future<Result> detectLicense(String text, double threshold) async {
  final granularity = computeGranularity(threshold);

  final unknownLicense = LicenseWithNGrams.parse(
      License.parse(identifier: '', content: text), granularity);

  final possibleLicenses =
      filter(unknownLicense.tokenFrequency, await _getDefaultLicenses())
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
      calculateUnclaimedTokenPercentage(result, unknownLicense.tokens.length);
  final longestUnclaimedTokenCount =
      findLongestUnclaimedTokenRange(result, unknownLicense.tokens.length);
  return Result(List.unmodifiable(result), unclaimedPercentage,
      longestUnclaimedTokenCount);
}

/// Returns the minimum number of token runs that must match according to
/// [threshold] to be able to consider it as match.
///
/// In a worst case scenario where the error is evenly
/// distributed (breaking the token runs most times), if we
/// consider 100 tokens and threshold 0.8, we'll have
/// 4 continuous matching tokens and a mismatch.
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

/// Determines each [LicenseMatch] in [matches] that has the highest confidence
/// among all [LicenseMatch] with the same [LicenseMatch.identifier].
@visibleForTesting
List<LicenseMatch> removeDuplicates(List<LicenseMatch> matches) {
  var identifierToLicense = <String, LicenseMatch>{};

  for (var match in matches) {
    if (identifierToLicense.containsKey(match.identifier)) {
      var prevMatch = identifierToLicense[match.identifier];
      // As both the licenses are same consider the
      // max of tokens claimed among these two.
      var tempMatch =
          prevMatch!.confidence > match.confidence ? prevMatch : match;

      tempMatch = tempMatch.updateTokenIndex(
        min(prevMatch.tokenRange.start, match.tokenRange.start),
        max(prevMatch.tokenRange.end, match.tokenRange.end),
      );

      identifierToLicense[match.identifier] = tempMatch;
      continue;
    }

    identifierToLicense[match.identifier] = match;
  }

  return identifierToLicense.values.toList();
}

/// Custom comparator to the sort the licenses based on
/// decreasing order of confidence.
///
/// In case the confidence detected is same for the matches,
/// the ratio of tokens claimed in the unknown text to the
/// number of tokens present in the known license text is considered
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

/// Filters out licenses having overlapping ranges,
/// giving preference to a match with higher token density.
///
/// Token density is the product of number of tokens claimed in the range and
/// confidence score of the match. In case of an exact match we retain both
/// the matches so that the user can resolve them.
@visibleForTesting
List<LicenseMatch> removeOverLappingMatches(List<LicenseMatch> matches) {
  var retain = List.filled(matches.length, false);
  var retainedMatches = <LicenseMatch>[];

  // We consider token density to retain matches of larger licenses
  // having lesser confidence when compared to a smaller license
  // having a perfect match.
  for (var i = 0; i < matches.length; i++) {
    var keep = true;
    final matchA = matches[i];
    final rangeA = Range(matchA.tokenRange.start, matchA.tokenRange.end);

    var proposals = <int, bool>{};
    for (var j = 0; j < matches.length; j++) {
      if (j == i) {
        break;
      }
      final matchB = matches[j];
      final rangeB = Range(matchB.tokenRange.start, matchB.tokenRange.end);
      // Check if matchA is larger license containing an instance of
      // smaller license within it and decide to whether retain it
      // or not by comparing their token densities. Example NPL
      // contains MPL.
      if (rangeA.contains(rangeB) && retain[j]) {
        final aConf = matchA.tokensClaimed * matchA.confidence;
        final bConf = matchB.tokensClaimed * matchB.confidence;

        // Retain both the licenses in case of an exact match,
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
      retainedMatches.add(matches[i]);
    }
  }

  return retainedMatches;
}

/// Returns the ratio of tokens claimed in all the matches to the number of
/// tokens present in the unknown license.
///
/// Minimum possible score is 0 in case none of the known licenses are detected.
/// The maximum score can be greater than 1 in cases where the same range of
/// tokens is claimed for two licenses.
///
/// For example NPL contains MPL in this case we detect 2 licenses in the
/// same range and hence we have a possibility of getting a score
/// than 1.
double calculateUnclaimedTokenPercentage(
    List<LicenseMatch> matches, int unknownTokensCount) {
  var claimedTokenCount = 0;

  for (var match in matches) {
    claimedTokenCount += match.tokensClaimed;
  }

  return max(0, (unknownTokensCount - claimedTokenCount) / unknownTokensCount);
}

/// Returns the number of tokens in the longest unclaimed token
/// sequence.
int findLongestUnclaimedTokenRange(List<LicenseMatch> matches, int end) {
  var ranges = <Range>[];
  if (matches.isEmpty) return end;

  for (var match in matches) {
    ranges.add(Range(match.tokenRange.start, match.tokenRange.end));
  }

  ranges.sort(sortRangeOnStartValue);
  var maxTokenSequence = ranges.first.start - 0;

  for (var i = 1; i < ranges.length; i++) {
    maxTokenSequence =
        max(ranges[i].start - ranges[i - 1].end, maxTokenSequence);
  }

  maxTokenSequence = max(maxTokenSequence, end - ranges.last.end);
  return maxTokenSequence;
}

int sortRangeOnStartValue(Range a, Range b) => a.start - b.start;
