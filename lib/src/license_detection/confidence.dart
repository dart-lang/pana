// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'license_detector.dart';

class LicensesMismatchException implements Exception {
  final int code;
  final String identifier;

  LicensesMismatchException(this.code, this.identifier);

  String _change() {
    switch (code) {
      case -1:
        return 'version change';
      case -2:
        return 'lesser GPL change';
    }

    return 'confidence lesser than threshold';
  }

  @override
  String toString() {
    return 'License mismatched with $identifier due to $_change';
  }
}

/// Computes the confidence of [knownLicense] matching with [unknownLicense] and
/// returns an instance of [LicenseMatch] or null based on it.
@visibleForTesting
LicenseMatch licenseMatch(
  LicenseWithNGrams unknownLicense,
  LicenseWithNGrams knownLicense,
  MatchRange matchRange,
  double threshold,
) {
  final diffs = getDiffs(
    unknownLicense.tokens,
    knownLicense.tokens,
    matchRange,
  );

  final range = diffRange(tokensNormalizedValue(knownLicense.tokens), diffs);
  final valuationDiffs = diffs.skip(range.start).take(range.end - range.start);

  // Make an initial check on the diffs to see if their are any
  // unacceptable substitutions made.
  //
  // As delete diffs are ordered before insert diffs, we store the
  // previously deleted diff and then compare with insert diff to
  // check if this substitution is valid or not. If we come across
  // an invalid substitution return a negative score indicating a
  // mismatch.
  verifyNoVersionChange(valuationDiffs, knownLicense.identifier);
  verifyNoGplChange(valuationDiffs, knownLicense.identifier);

  final distance = scoreDiffs(diffs);
  final confidence = confidencePercentage(knownLicense.tokens.length, distance);

  if (confidence < threshold) {
    throw LicensesMismatchException(0, knownLicense.identifier);
  }

  final match = LicenseMatch(
    unknownLicense.tokens
        .skip(matchRange.input.start)
        .take(matchRange.input.end - matchRange.input.start)
        .toList(),
    confidence,
    knownLicense,
    diffs,
    Range(range.start, range.end),
  );

  return match;
}

/// Calculates the confidence percentage as 1 subtracted by the ratio of
/// Levenshtein word distance to the number of tokens in known license.
@visibleForTesting
double confidencePercentage(int knownLength, int distance) {
  if (knownLength == 0) {
    return 1.0;
  }
  final confidence = 1.0 - (distance / knownLength);

  return confidence;
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
///
/// The range provides diffs from which the unknown text could be trimmed down to
/// produce best resemble known text. Essentially it tries to remove parts of
/// text in unknown license which are not a part of known license without affecting the
/// confidence negatively i.e any false-negatives are not discarded while some of the
/// true-negatives are discarded.
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

/// Throws if there was a change with the unknown license.
void verifyNoVersionChange(Iterable<Diff> diffs, String identifier) {
  var prevText = '';

  for (var diff in diffs) {
    final text = diff.text;

    if (diff.operation == Operation.insert) {
      var number = text;
      final index = text.indexOf(' ');

      if (index != -1) {
        number = number.substring(0, index);
      }

      if (_isVersionNumber(number) && prevText.endsWith('version')) {
        if (!prevText.endsWith('the standard version') &&
            !prevText.endsWith('the contributor version')) {
          throw LicensesMismatchException(-1, identifier);
        }
      }
    } else if (diff.operation == Operation.equal) {
      prevText = text;
    }
  }
}

///
void verifyNoGplChange(Iterable<Diff> diffs, String identifier) {
  var prevText = '';
  var prevDelete = '';

  for (var diff in diffs) {
    final text = diff.text;

    switch (diff.operation) {
      case Operation.insert:

        // Ignores substitution of "library" with "lesser" in gnu license,
        // but looks for other additions of "lesser" that would lead to
        // a mismatch.
        if (text == 'lesser' &&
            prevText.endsWith('gnu') &&
            prevDelete != 'library') {
          if (!prevText.contains('warranty')) {
            throw LicensesMismatchException(lesserGplChange, identifier);
          }
        }
        break;

      case Operation.delete:
        if (text == 'lesser' && prevText.endsWith('gnu')) {
          if (!prevText.contains('warranty')) {
            throw LicensesMismatchException(lesserGplChange, identifier);
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
}

/// Returns a score indicating to what extent the [diffs] are acceptable.
///
/// The integer returned indicates the Levenshtein edit distance
/// calculated on the number of words altered instead of
/// the number of characters altered.
@visibleForTesting
int scoreDiffs(Iterable<Diff> diffs) {
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
