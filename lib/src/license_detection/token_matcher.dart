// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'license_detector.dart';

/// Range of tokens in input text that matched to a range of tokens in known license.
@sealed
@visibleForTesting
class MatchRange {
  /// Range of tokens that were found to be a match in input text.
  final Range input;

  /// Range of tokens that were found to be a match in known license.
  final Range source;

  /// Number of tokens that were matched in this range.
  final int tokensClaimed;

  @visibleForTesting
  MatchRange(
    this.input,
    this.source,
    this.tokensClaimed,
  );

  MatchRange update(
      {int? inputStart,
      int? inputEnd,
      int? srcStart,
      int? srcEnd,
      int? newClaim}) {
    final newInput = Range(inputStart ?? input.start, inputEnd ?? input.end);
    final newSource = Range(srcStart ?? source.start, srcEnd ?? source.end);
    return MatchRange(newInput, newSource, newClaim ?? tokensClaimed);
  }
}

/// Indicates the start and end index for a range.
@sealed
@visibleForTesting
class Range {
  Range(this.start, this.end);

  /// Start index of the token in this range.
  final int start;

  /// End index(exclusive) of the token in this range.
  final int end;

  bool contains(Range other) {
    return other.start >= start && other.end <= end;
  }

  bool overlapsWith(Range other) {
    return (start >= other.start && start <= other.end) ||
        (end >= other.start && end <= other.end);
  }
}

/// Returns a list of [MatchRange] for [unknownLicense] that might be the best possible match for [knownLicense].
@visibleForTesting
List<MatchRange> findPotentialMatches(
  LicenseWithNGrams unknownLicense,
  LicenseWithNGrams knownLicense,
  double confidence,
) {
  if (knownLicense.granularity != unknownLicense.granularity) {
    throw ArgumentError(
        'n-gram size for knownLicense and unknownLicense must be the same!');
  }

  final matchedRanges = getMatchRanges(
    unknownLicense,
    knownLicense,
    confidence,
    knownLicense.granularity,
  );

  // Minimum number of tokens that range must have to be considered a possible match.
  final threshold = (confidence * knownLicense.tokens.length).toInt();

  for (var i = 0; i < matchedRanges.length; i++) {
    if (matchedRanges[i].tokensClaimed < threshold) {
      return List.unmodifiable(matchedRanges.take(i));
    }
  }

  return List.unmodifiable(matchedRanges);
}

/// Returns a list of [MatchRange] for tokens in [input] that were found to be a match for [source].
@visibleForTesting
List<MatchRange> getMatchRanges(
  LicenseWithNGrams input,
  LicenseWithNGrams source,
  double confidence,
  int n,
) {
  // Collect all the matches irrespective of the number of tokens claimed
  // in the range (Can be less then the threshold number of tokens).
  final matches = getTargetMatchedRanges(source, input, n);

  if (matches.isEmpty) {
    return [];
  }

  // Analyse all the matches that were found and figure out which
  final runs = detectRuns(
    matches,
    confidence,
    input.tokens.length,
    source.tokens.length,
    n,
  );

  if (runs.isEmpty) {
    return [];
  }

  return fuseMatchedRanges(
      matches, confidence, source.tokens.length, runs, input.tokens.length);
}

/// Returns a list of [MatchRange] for all the continuous range of [Ngram](s) matched in [unknownLicense] and [knownLicense].
@visibleForTesting
List<MatchRange> getTargetMatchedRanges(
  LicenseWithNGrams knownLicense,
  LicenseWithNGrams unknownLicense,
  int n,
) {
  var offsetMap = <int, List<MatchRange>>{};
  var matches = <MatchRange>[];

  for (var tgtChecksum in unknownLicense.nGrams) {
    var srcChecksums = knownLicense.checksumMap[tgtChecksum.checksum];

    // Check if source contains the checksum.
    if (srcChecksums == null) {
      continue;
    }
    // Iterate over all the trigrams in source having the same checksums.
    for (var i = 0; i < srcChecksums.length; i++) {
      var srcChecksum = srcChecksums[i];
      final offset = tgtChecksum.start - srcChecksum.start;

      // Check if this source checksum extend the last match
      // and update the last match for this offset accordingly.
      var matches = offsetMap[offset];
      if (matches != null && (matches.last.input.end == tgtChecksum.end - 1)) {
        matches.last = matches.last.update(
          inputEnd: tgtChecksum.end,
          srcEnd: srcChecksum.end,
        );
        offsetMap[offset] = matches;
        continue;
      }

      // Add new instance of matchRange if doesn't extend the last
      // match of the same offset.
      offsetMap.putIfAbsent(offset, () => []).add(
            MatchRange(Range(tgtChecksum.start, tgtChecksum.end),
                Range(srcChecksum.start, srcChecksum.end), n),
          );
    }
  }

  for (var list in offsetMap.values) {
    // Update the token count of match range.
    for (var match in list) {
      final start = match.input.start;
      final end = match.input.end;
      match = match.update(newClaim: end - start);
      matches.add(match);
    }
  }

  // Sort the matches based on the number of tokens covered in match
  // range in descending order.
  matches.sort(_compareTokenCount);
  return List.unmodifiable(matches);
}

/// Returns list of [MatchRange] for all the clusters of ordered [NGram] in unknownLicense that might be a potential match to the knownLicense.
///
/// For a sequence of N tokens to be considered a potential match,
/// it should have at least (N * [confidenceThreshold]) number of tokens
/// that appear in at least in one matching [NGram].
@visibleForTesting
List<Range> detectRuns(
  List<MatchRange> matches,
  double confidenceThreshold,
  final int inputTokensCount,
  final int licenseTokenCount,
  int n,
) {
  // Set the subset length to smaller of the number of input tokens
  // or number of source tokens.
  //
  // If the input has lesser number of tokens than the source
  // i.e target doesn't has at least one subset of source
  // we decrease the subset length to number of tokens in the
  // input and analyse what we have.
  final subsetLength = inputTokensCount < licenseTokenCount
      ? inputTokensCount
      : licenseTokenCount;

  // Minimum number of tokens that must match in a window of subsetLength
  // to consider it a possible match.
  final targetTokens = (confidenceThreshold * subsetLength).toInt();
  var hits = List<bool>.filled(inputTokensCount, false);

  for (var match in matches) {
    for (var i = match.input.start; i < match.input.end; i++) {
      hits[i] = true;
    }
  }

  // Initialize the total number of matches for the first window
  // i.e [0,subsetLength).
  var totalMatches = hits.take(subsetLength).where((element) => element).length;

  var out = <int>[];
  if (totalMatches >= targetTokens) {
    out.add(0);
  }

  // Slide the window to right and keep on updating the number
  // of hits. If the total number of hits is greater than
  // the confidence threshold add it to the output list.
  for (var i = 1; i < inputTokensCount; i++) {
    // Check if the start of the last window was a
    // hit and decrease the total count.
    if (hits[i - 1]) {
      totalMatches--;
    }

    final end = i + subsetLength - 1;

    // Similarly check if the last value of the updated window is a hit
    // and update the total count accordingly.
    if (end < inputTokensCount && hits[end]) {
      totalMatches++;
    }

    if (totalMatches >= targetTokens) {
      out.add(i);
    }
  }

  if (out.isEmpty) {
    return [];
  }

  var finalOut = <Range>[
    Range(
      out[0],
      out[0] + n,
    )
  ];

  // Create a list of matchRange from the token indexes that were
  // were considered to be a potential match.
  for (var i = 1; i < out.length; i++) {
    if (out[i] != 1 + out[i - 1]) {
      finalOut.add(Range(out[i], out[i] + n));
    } else {
      finalOut.last = Range(finalOut.last.start, out[i] + n);
    }
  }

  return List.unmodifiable(finalOut);
}

/// Analyze and combine [matches] with no error into larger range of matches with some tolerable amount of error.
///
/// All the [matches] detected having no false positives are
/// compared with each other to check if they can be merged with
/// each other to produce larger [MatchRange] that might have enough
/// number of tokens to be considered a match for input text while
/// keeping the error within a certain margin.
@visibleForTesting
List<MatchRange> fuseMatchedRanges(
  List<MatchRange> matches,
  double confidence,
  int size,
  List<Range> runs,
  int targetSize,
) {
  var claimed = <MatchRange>[];
  final errorMargin = (size * (1 - confidence)).round();

  var filter = List.filled(targetSize, false);

  for (var match in runs) {
    for (var i = match.start; i < match.end; i++) {
      filter[i] = true;
    }
  }

  for (var match in matches) {
    var offset = match.input.start - match.source.start;

    if (offset < 0) {
      if (-offset <= errorMargin) {
        offset = 0;
      } else {
        continue;
      }
    }

    // If filter is false this implies that there were not enough instances of
    // match in this range, so this is a spurious hit and is discarded.
    if (!filter[offset]) {
      continue;
    }

    var unclaimed = true;

    final matchOffset = match.input.start - match.source.start;
    for (var i = 0; i < claimed.length; i++) {
      var claim = claimed[i];
      var claimOffset = claim.input.start - claim.source.start;

      var sampleError = (matchOffset - claimOffset).abs();
      final withinError = sampleError < errorMargin;

      if (withinError && (match.tokensClaimed > sampleError)) {
        // Check if this match lies within the claim, if does just update the number
        // of token count.
        if (match.input.start >= claim.input.start &&
            match.input.end <= claim.input.end) {
          claim =
              claim.update(newClaim: claim.tokensClaimed + match.tokensClaimed);
          unclaimed = false;
        }
        // Check if the claim and match can be merged.
        else {
          // Match is within error margin and claim is likely to
          // be an extension of match. So we update the input and
          // source start offsets of claim.
          if (match.input.start < claim.input.start &&
              match.source.start < claim.source.start) {
            claim = claim.update(
              inputStart: match.input.start,
              srcStart: match.source.start,
              newClaim: claim.tokensClaimed + match.tokensClaimed,
            );

            unclaimed = false;
          }
          // Match is within error margin and match is likely to
          // to extend claim. So we update the input and source
          // end offsets of claim.
          else if (match.input.end > claim.input.end &&
              match.source.end > claim.source.end) {
            claim = claim.update(
              inputEnd: match.input.end,
              srcEnd: match.source.end,
              newClaim: claim.tokensClaimed + match.tokensClaimed,
            );
            unclaimed = false;
          }
        }

        // The match does not extend any existing claims, and
        // can be added as a new claim.
      }

      claimed[i] = claim;
      if (!unclaimed) {
        break;
      }
    }

    // Add as a new claim if it is relevant and has higher quality of
    // hits.
    if (unclaimed && match.tokensClaimed * 10 > matches[0].tokensClaimed) {
      claimed.add(match);
    }
  }

  claimed.sort(_compareTokenCount);

  return claimed;
}

/// [Comparator] to sort list of [MatchRange] in descending order of the number of
/// token claimed in range.
int _compareTokenCount(
  MatchRange a,
  MatchRange b,
) =>
    b.tokensClaimed - a.tokensClaimed;
