// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/diff.dart';
import 'package:pana/src/license_detection/license.dart';
import 'package:pana/src/license_detection/token_matcher.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

/// Computes the confidence of [knownLicense] matching with [unknownLicense] and
/// returns an instance of [LicenseMatch] or null based on it.
LicenseMatch? confidenceMatch(
  PossibleLicense unknownLicense,
  PossibleLicense knownLicense,
  MatchRange matchRange,
  double threshold,
) {
  final diffs = getDiffs(
    unknownLicense.license.tokens,
    knownLicense.license.tokens,
    matchRange,
  );

  final range =
      diffRange(tokensNormalizedValue(knownLicense.license.tokens), diffs);
  final distance = scoreDiffs(diffs.skip(range.start).take(range.end));

  // If distance is negative it implies an we have an unaccepatable diff,
  // therefore we return null.
  if (distance < 0) {
    return null;
  }

  final confidence =
      confidencePercentage(knownLicense.license.tokens.length, distance);

  if (confidence >= threshold) {
    return LicenseMatch(
      unknownLicense.license.tokens
          .skip(matchRange.input.start)
          .take(
            matchRange.input.end - matchRange.input.start,
          )
          .toList(),
      confidence,
      knownLicense.license,
      diffs,
      Range(range.start, range.end),
    );
  }

  // If confidence is not greater than or equal to threshold don't
  // return any match.
  return null;
}

/// Calculates the confidence percentange as 1 subtracted by the ratio of
/// Levenshtein word [distance] to the number of tokens in known license.
@visibleForTesting
double confidencePercentage(int knownLength, int distance) {
  if (knownLength == 0) {
    return 1.0;
  }

  return 1.0 - (distance / knownLength);
}

@visibleForTesting
List<Diff> getDiffs(
  List<Token> inputTokens,
  List<Token> knownTokens,
  MatchRange matchRange,
) {
  final dmp = DiffMatchPatch();

  final unknownText = tokensNormalizedValue(inputTokens
      .skip(matchRange.input.start)
      .take(matchRange.input.end - matchRange.input.start));

  final knownText = tokensNormalizedValue(
    knownTokens.take(matchRange.source.end),
  );

  final diffs = dmp.diffMain(unknownText, knownText);

  dmp.diffCleanupSemantic(diffs);

  return List.unmodifiable(diffs);
}

/// Returns the range in [diffs] that best resembles the known license text.
@visibleForTesting
Range diffRange(String known, List<Diff> diffs) {
  var foundStart = false;
  var seen = '';
  var end = 0;
  var start = 0;

  for (end = 0; end < diffs.length; end++) {
    if (seen.length > 1 && seen.trimRight() == known) {
      break;
    }

    if (diffs[end].operation == Operation.insert ||
        diffs[end].operation == Operation.equal) {
      if (!foundStart) {
        start = end;
        foundStart = true;
      }

      seen += diffs[end].text + ' ';
    }
  }

  return Range(start, end);
}

/// Returns a score indicating to how much extent the [diffs] are acceptable.
///
/// If a negative integer is returned it implies that the changes are not
/// accepatable and hence we discard the known license against which the diffs
/// were calculated.
///
/// If a positive integer is returned it indicates the Levenshtein edit
/// distance calculated on the number of words altered instead of
/// the number of characters altered.
@visibleForTesting
int scoreDiffs(Iterable<Diff> diffs) {
  var prevText = '';
  var prevDelete = '';

  // Make an initial check on the diffs to see if their are any
  // unacceptable substitutions made.
  //
  // As delete diffs are ordered before insert diffs, we store the
  // previously deleted diff and then compare with insert diff to
  // check if this substitution is valid or not. If we come across
  // an invalid substitution return a negative score indicating a
  // mismatch.
  for (var diff in diffs) {
    final text = diff.text;

    switch (diff.operation) {
      case Operation.insert:
        var number = text;
        final index = text.indexOf(' ');

        if (index != -1) {
          number = number.substring(0, index);
        }

        // Check if there was a version change and return -1.
        if (_isVersionNumber(number) && prevText.endsWith('version')) {
          if (!prevText.endsWith('the standard version') &&
              !prevText.endsWith('the contributor version')) {
            return versionChange;
          }
        }

        // Ignores substitution of "library" with "lesser" in gnu license,
        // but looks for other additions of "lesser" that would lead to
        // a mismatch.
        if (text == 'lesser' &&
            prevText.endsWith('gnu') &&
            prevDelete != 'library') {
          if (!prevText.contains('warranty')) {
            return lesserGplChange;
          }
        }
        break;

      case Operation.delete:
        if (text == 'lesser' && prevText.endsWith('gnu')) {
          if (!prevText.contains('warranty')) {
            return lesserGplChange;
          }
        }

        prevDelete = text;
        break;

      case Operation.equal:
        prevText = text;
        prevDelete = '';
        break;
    }
  }

  return diffLevenshteinWord(diffs);
}

final _notVersionNumber = RegExp(r'[^0-9\.]');

bool _isVersionNumber(String text) {
  return !_notVersionNumber.hasMatch(text);
}

@visibleForTesting
const versionChange = -1;

@visibleForTesting
const lesserGplChange = -2;

// final _inducedPhrases = {
// 				'AGPL':                             ['affero'],
// 				'Atmel':                            ['atmel'],
// 				'Apache':                           ['apache'],
// 				'BSD':                              ['bsd'],
// 				'BSD-3-Clause-Attribution':         ['acknowledgment'],
// 				'bzip2':                            ['seward'],
// 				'GPL-2.0-with-GCC-exception':       ['gcc linking exception'],
// 				'GPL-2.0-with-autoconf-exception':  ['autoconf exception'],
// 				'GPL-2.0-with-bison-exception':     ['bison exception'],
// 				'GPL-2.0-with-classpath-exception': ['class path exception'],
// 				'GPL-2.0-with-font-exception':      ['font exception]',
// 				'LGPL-2.0':                         ['library'],
// 				'ImageMagick':                      ['imagemagick'],
// 				'PHP':                              ['php'],
// 				'SISSL':                            ['sun standards'],
// 				'SGI-B':                            ['silicon graphics'],
// 				'X11':                              ['x consortium'],
// };
