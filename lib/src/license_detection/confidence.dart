// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'license_detector.dart';

/// An instance indicating a mismatch between unknown text and a known license.
@sealed
@visibleForTesting
class LicenseMismatchException implements Exception {
  final String message;

  LicenseMismatchException(this.message);

  @override
  String toString() {
    return message;
  }
}

/// Computes the confidence of [knownLicense] matching with [unknownLicense] and
/// returns an instance of [LicenseMatch].
///
/// Throws [LicenseMismatchException] if an unaccepatable change was made or the calculated confidence is
/// lesser than the set threshold.
@visibleForTesting
LicenseMatch licenseMatch(
  LicenseWithNGrams unknownLicense,
  LicenseWithNGrams knownLicense,
  MatchRange matchRange,
  double threshold,
) {
  if (unknownLicense.granularity != knownLicense.granularity) {
    throw LicenseMismatchException(
        "Can't comapare the licenses due to different granularity");
  }
  final diffs = getDiffs(
    unknownLicense.tokens,
    knownLicense.tokens,
    matchRange,
  );

  final range = diffRange(normalizedContent(knownLicense.tokens), diffs);
  final valuationDiffs = diffs.skip(range.start).take(range.end - range.start);

  // Make an initial check on the diffs to see if their are any
  // unacceptable substitutions made.
  verifyNoVersionChange(valuationDiffs, knownLicense.identifier);
  verifyNoGplChange(valuationDiffs, knownLicense.identifier);
  verifyInducedPhraseChange(knownLicense.identifier, valuationDiffs);

  final distance = scoreDiffs(valuationDiffs);
  final confidence = confidencePercentage(
    knownLicense.tokens.length,
    distance,
  );

  if (confidence < threshold) {
    throw LicenseMismatchException(
        'Confidence $confidence is less than threshold $threshold');
  }

  return LicenseMatch(
    unknownLicense.tokens
        .skip(matchRange.input.start)
        .take(matchRange.input.end - matchRange.input.start)
        .toList(),
    confidence,
    knownLicense,
    diffs,
    Range(range.start, range.end),
  );
}

/// Calculates the confidence percentage as 1 subtracted by the ratio of
/// Levenshtein word distance to the number of tokens in known license.
@visibleForTesting
double confidencePercentage(int knownLength, int distance) {
  if (knownLength == 0) {
    return 1.0;
  }
  assert(distance <= knownLength);
  final confidence = 1.0 - (distance / knownLength);

  return confidence;
}

@visibleForTesting
List<Diff> getDiffs(
  List<Token> inputTokens,
  List<Token> knownTokens,
  MatchRange matchRange,
) {
  final unknownText = normalizedContent(inputTokens
      .skip(matchRange.input.start)
      .take(matchRange.input.end - matchRange.input.start));

  final knownText = normalizedContent(
    knownTokens.take(matchRange.source.end),
  );

  final diffs = diffMain(unknownText, knownText);

  diffCleanupEfficiency(diffs);

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
  final diffLength = diffs.length;

  for (end = 0; end < diffLength; end++) {
    if (seen.trimRight() == known) {
      break;
    }

    if (seen.length > 1 && !known.startsWith(seen)) {
      end = diffLength;
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

/// Ths function checks if a version change was made.
///
/// As delete diffs are ordered before insert diffs, we store the
/// previously deleted diff and then compare with insert diff to
/// check if this substitution introduced a version change.
///
/// Throws [LicenseMismatchException] if a version change was made.
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
          throw LicenseMismatchException(
              'License does not match due to version change');
        }
      }
    } else if (diff.operation == Operation.equal) {
      prevText = text;
    }
  }
}

/// There are certain phrases that can't be introduced to make a license hit.
///
/// Throws a [LicenseMismatchException] if such a phrase was induced.
void verifyInducedPhraseChange(String licenseId, Iterable<Diff> diffs) {
  var presentInList = false;
  var inducedPhraseList = <String>[];

  for (var key in _inducedPhrases.keys) {
    if (licenseId.startsWith(key)) {
      presentInList = true;
      inducedPhraseList = _inducedPhrases[key]!;
      break;
    }
  }

  if (!presentInList) {
    return;
  }

  for (var diff in diffs) {
    final text = diff.text;

    if (diff.operation == Operation.insert) {
      for (var phrase in inducedPhraseList) {
        if (text.contains(phrase)) {
          throw LicenseMismatchException('Induced phrase change');
        }
      }
    }
  }
}

/// Checks if minor changes are introducing a mismatch between GPL and LGPL.
///
/// Throws [LicenseMismatchException] if there is a mismatch.
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
            throw LicenseMismatchException(
                'License does not match with $identifier due to lesser GPL change');
          }
        }
        break;

      case Operation.delete:
        if (text == 'lesser' && prevText.endsWith('gnu')) {
          if (!prevText.contains('warranty')) {
            throw LicenseMismatchException(
                'License does not match with $identifier due to lesser GPL change');
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

/// Checks if [text] contains anything other than 0-9 and `.`.
bool _isVersionNumber(String text) => !_notVersionNumber.hasMatch(text);

@visibleForTesting
const versionChange = -1;

@visibleForTesting
const lesserGplChange = -2;

final _inducedPhrases = {
  'AGPL': ['affero'],
  'Atmel': ['atmel'],
  'Apache': ['apache'],
  'BSD': ['bsd'],
  'BSD-3-Clause-Attribution': ['acknowledgment'],
  'bzip2': ['seward'],
  'GPL-2.0-with-GCC-exception': ['gcc linking exception'],
  'GPL-2.0-with-autoconf-exception': ['autoconf exception'],
  'GPL-2.0-with-bison-exception': ['bison exception'],
  'GPL-2.0-with-classpath-exception': ['class path exception'],
  'GPL-2.0-with-font-exception': ['font exception'],
  'LGPL-2.0': ['library'],
  'ImageMagick': ['imagemagick'],
  'PHP': ['php'],
  'SISSL': ['sun standards'],
  'SGI-B': ['silicon graphics'],
  'X11': ['x consortium'],
};
