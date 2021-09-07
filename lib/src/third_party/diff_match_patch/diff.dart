// Diff Match and Patch
// Copyright 2018 The diff-match-patch Authors.
// https://github.com/google/diff-match-patch
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:collection';
import 'dart:math';

import 'package:meta/meta.dart';

part 'utils.dart';

enum Operation { delete, insert, equal }

/// Class representing one diff operation.
class Diff {
  /// One of: Operation.insert, Operation.delete or Operation.equal.
  Operation operation;

  /// The text associated with this diff operation.
  String text;

  /// Constructor.  Initializes the diff with the provided values.
  ///
  /// [operation] is one of Operation.insert, Operation.delete or Operation.equal.
  /// [text] is the text being applied.
  Diff(this.operation, this.text);

  /// Display a human-readable version of this Diff.
  /// Returns a text version.
  @override
  String toString() {
    var prettyText = text.replaceAll('\n', '\u00b6');
    return 'Diff($operation,"$prettyText")';
  }

  /// Is this Diff equivalent to another Diff?
  /// [other] is another Diff to compare against.
  /// Returns true or false.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Diff &&
          runtimeType == other.runtimeType &&
          operation == other.operation &&
          text == other.text;

  /// Generate a uniquely identifiable hashcode for this Diff.
  /// Returns numeric hashcode.
  @override
  int get hashCode => operation.hashCode ^ text.hashCode;
}

double diffTimeout = 1.0;

/// Find the differences between two texts.
///
/// Simplifies the problem by stripping any common prefix or suffix
/// off the texts before diffing.
/// [text1] is the old string to be diffed.
/// [text2] is the new string to be diffed.
/// [checklines] is an optional speedup flag.  If present and false, then don't
/// run a line-level diff first to identify the changed areas.
/// Defaults to true, which does a faster, slightly less optimal diff.
/// [deadline] is an optional time when the diff should be complete by.  Used
/// internally for recursive calls.  Users should set DiffTimeout instead.
/// Returns a List of Diff objects.
List<Diff> diffMain(
  String text1,
  String text2, {
  bool checklines = true,
  DateTime? deadline,
}) {
  // Set a deadline by which time the diff must be complete.
  if (deadline == null) {
    deadline = DateTime.now();
    if (diffTimeout <= 0) {
      // One year should be sufficient for 'infinity'.
      deadline = deadline.add(const Duration(days: 365));
    } else {
      deadline =
          deadline.add(Duration(milliseconds: (diffTimeout * 1000).toInt()));
    }
  }

  // Check for equality (speedup).
  var diffs = <Diff>[];
  if (text1 == text2) {
    if (text1.isNotEmpty) {
      diffs.add(Diff(Operation.equal, text1));
    }
    return diffs;
  }

  // Trim off common prefix (speedup).
  var commonlength = diffCommonPrefix(text1, text2);
  var commonprefix = text1.substring(0, commonlength);
  text1 = text1.substring(commonlength);
  text2 = text2.substring(commonlength);

  // Trim off common suffix (speedup).
  commonlength = diffCommonSuffix(text1, text2);
  var commonsuffix = text1.substring(text1.length - commonlength);
  text1 = text1.substring(0, text1.length - commonlength);
  text2 = text2.substring(0, text2.length - commonlength);

  // Compute the diff on the middle block.
  diffs = diffCompute(text1, text2, checklines, deadline);

  // Restore the prefix and suffix.
  if (commonprefix.isNotEmpty) {
    diffs.insert(0, Diff(Operation.equal, commonprefix));
  }
  if (commonsuffix.isNotEmpty) {
    diffs.add(Diff(Operation.equal, commonsuffix));
  }

  diffCleanupMerge(diffs);
  return diffs;
}

/// Find the differences between two texts.
///
/// Assumes that the texts do not have any common prefix or suffix.
/// [text1] is the old string to be diffed.
/// [text2] is the new string to be diffed.
/// [checklines] is a speedup flag.  If false, then don't run a
/// line-level diff first to identify the changed areas.
/// If true, then run a faster slightly less optimal diff.
/// [deadline] is the time when the diff should be complete by.
/// Returns a List of Diff objects.
@visibleForTesting
List<Diff> diffCompute(
  String text1,
  String text2,
  bool checklines,
  DateTime deadline,
) {
  var diffs = <Diff>[];

  if (text1.isEmpty) {
    // Just add some text (speedup).
    diffs.add(Diff(Operation.insert, text2));
    return diffs;
  }

  if (text2.isEmpty) {
    // Just delete some text (speedup).
    diffs.add(Diff(Operation.delete, text1));
    return diffs;
  }

  final longText = text1.length > text2.length ? text1 : text2;
  final shortText = text1.length > text2.length ? text2 : text1;

  final i = longText.indexOf(shortText);

  if (i != -1) {
    // Shorter text is inside the longer text (speedup).
    final op =
        (text1.length > text2.length) ? Operation.delete : Operation.insert;

    diffs.add(Diff(op, longText.substring(0, i)));
    diffs.add(Diff(Operation.equal, shortText));
    diffs.add(Diff(op, longText.substring(i + shortText.length)));
    return diffs;
  }

  if (shortText.length == 1) {
    // Single character string.
    // After the previous speedup, the character can't be an equality.
    diffs.add(Diff(Operation.delete, text1));
    diffs.add(Diff(Operation.insert, text2));
    return diffs;
  }

  // Check to see if the problem can be split in two.
  final hm = diffHalfMatch(text1, text2);

  if (hm != null) {
    // A half-match was found, sort out the return data.
    final text1A = hm[0];
    final textB = hm[1];
    final text2A = hm[2];
    final text2B = hm[3];
    final midCommon = hm[4];
    // Send both pairs off for separate processing.
    final diffsA = diffMain(
      text1A,
      text2A,
      checklines: checklines,
      deadline: deadline,
    );

    final diffsB = diffMain(
      textB,
      text2B,
      checklines: checklines,
      deadline: deadline,
    );

    // Merge the results.
    diffs = diffsA;
    diffs.add(Diff(Operation.equal, midCommon));
    diffs.addAll(diffsB);
    return diffs;
  }

  if (checklines && text1.length > 100 && text2.length > 100) {
    return _diffLineMode(text1, text2, deadline);
  }

  return diffBisect(text1, text2, deadline);
}

/// Reorder and merge like edit sections. Merge equalities.
///
/// Any edit section can move as long as it doesn't cross an equality.
/// [diffs] is a List of Diff objects.
@visibleForTesting
void diffCleanupMerge(List<Diff> diffs) {
  diffs.add(Diff(Operation.equal, '')); // Add a dummy entry at the end.

  var pointer = 0;
  var countDelete = 0;
  var countInsert = 0;
  var textDelete = '';
  var textInsert = '';
  int commonlength;

  while (pointer < diffs.length) {
    switch (diffs[pointer].operation) {
      case Operation.insert:
        countInsert++;
        textInsert += diffs[pointer].text;
        pointer++;
        break;
      case Operation.delete:
        countDelete++;
        textDelete += diffs[pointer].text;
        pointer++;
        break;
      case Operation.equal:
        // Upon reaching an equality, check for prior redundancies.
        if (countDelete + countInsert > 1) {
          if (countDelete != 0 && countInsert != 0) {
            // Factor out any common prefixes.
            commonlength = diffCommonPrefix(textInsert, textDelete);
            if (commonlength != 0) {
              if ((pointer - countDelete - countInsert) > 0 &&
                  diffs[pointer - countDelete - countInsert - 1].operation ==
                      Operation.equal) {
                final i = pointer - countDelete - countInsert - 1;
                diffs[i].text =
                    diffs[i].text + textInsert.substring(0, commonlength);
              } else {
                diffs.insert(
                    0,
                    Diff(Operation.equal,
                        textInsert.substring(0, commonlength)));
                pointer++;
              }
              textInsert = textInsert.substring(commonlength);
              textDelete = textDelete.substring(commonlength);
            }

            // Factor out any common suffixes.
            commonlength = diffCommonSuffix(textInsert, textDelete);
            if (commonlength != 0) {
              diffs[pointer].text =
                  textInsert.substring(textInsert.length - commonlength) +
                      diffs[pointer].text;
              textInsert =
                  textInsert.substring(0, textInsert.length - commonlength);
              textDelete =
                  textDelete.substring(0, textDelete.length - commonlength);
            }
          }
          // Delete the offending records and add the merged ones.
          pointer -= countDelete + countInsert;
          diffs.removeRange(pointer, pointer + countDelete + countInsert);
          if (textDelete.isNotEmpty) {
            diffs.insert(pointer, Diff(Operation.delete, textDelete));
            pointer++;
          }
          if (textInsert.isNotEmpty) {
            diffs.insert(pointer, Diff(Operation.insert, textInsert));
            pointer++;
          }
          pointer++;
        } else if (pointer != 0 &&
            diffs[pointer - 1].operation == Operation.equal) {
          // Merge this equality with the previous one.
          diffs[pointer - 1].text =
              diffs[pointer - 1].text + diffs[pointer].text;
          diffs.removeAt(pointer);
        } else {
          pointer++;
        }
        countInsert = 0;
        countDelete = 0;
        textDelete = '';
        textInsert = '';
        break;
    }
  }
  if (diffs.last.text.isEmpty) {
    diffs.removeLast(); // Remove the dummy entry at the end.
  }

  // Second pass: look for single edits surrounded on both sides by equalities
  // which can be shifted sideways to eliminate an equality.
  // e.g: A<ins>BA</ins>C -> <ins>AB</ins>AC
  var changes = false;
  pointer = 1;
  // Intentionally ignore the first and last element (don't need checking).
  while (pointer < diffs.length - 1) {
    if (diffs[pointer - 1].operation == Operation.equal &&
        diffs[pointer + 1].operation == Operation.equal) {
      // This is a single edit surrounded by equalities.
      if (diffs[pointer].text.endsWith(diffs[pointer - 1].text)) {
        // Shift the edit over the previous equality.
        diffs[pointer].text = diffs[pointer - 1].text +
            diffs[pointer].text.substring(
                  0,
                  diffs[pointer].text.length - diffs[pointer - 1].text.length,
                );

        diffs[pointer + 1].text =
            diffs[pointer - 1].text + diffs[pointer + 1].text;

        diffs.removeAt(pointer - 1);
        changes = true;
      } else if (diffs[pointer].text.startsWith(diffs[pointer + 1].text)) {
        // Shift the edit over the next equality.
        diffs[pointer - 1].text =
            diffs[pointer - 1].text + diffs[pointer + 1].text;

        diffs[pointer].text =
            diffs[pointer].text.substring(diffs[pointer + 1].text.length) +
                diffs[pointer + 1].text;

        diffs.removeAt(pointer + 1);
        changes = true;
      }
    }
    pointer++;
  }
  // If shifts were made, the diff needs reordering and another shift sweep.
  if (changes) {
    diffCleanupMerge(diffs);
  }
}

/// Do the two texts share a substring which is at least half the length of the longer text?
///
/// This speedup can produce non-minimal diffs.
/// [text1] is the first string.
/// [text2] is the second string.
/// Returns a five element List of Strings, containing the prefix of text1,
/// the suffix of text1, the prefix of text2, the suffix of text2 and the
/// common middle.  Or null if there was no match.
@visibleForTesting
List<String>? diffHalfMatch(String text1, String text2) {
  if (diffTimeout <= 0) {
    // Don't risk returning a non-optimal diff if we have unlimited time.
    return null;
  }

  final longtext = text1.length > text2.length ? text1 : text2;
  final shorttext = text1.length > text2.length ? text2 : text1;

  if (longtext.length < 4 || shorttext.length * 2 < longtext.length) {
    return null; // Pointless.
  }

  // First check if the second quarter is the seed for a half-match.
  final hm1 = _diffHalfMatchI(
    longtext,
    shorttext,
    ((longtext.length + 3) / 4).ceil().toInt(),
  );

  // Check again based on the third quarter.
  final hm2 = _diffHalfMatchI(
    longtext,
    shorttext,
    ((longtext.length + 1) / 2).ceil().toInt(),
  );

  List<String>? hm;
  if (hm1 == null && hm2 == null) {
    return null;
  } else if (hm2 == null) {
    hm = hm1;
  } else if (hm1 == null) {
    hm = hm2;
  } else {
    // Both matched.  Select the longest.
    hm = hm1[4].length > hm2[4].length ? hm1 : hm2;
  }

  // A half-match was found, sort out the return data.
  if (text1.length > text2.length) {
    return hm;
    //return [hm[0], hm[1], hm[2], hm[3], hm[4]];
  } else {
    return [hm![2], hm[3], hm[0], hm[1], hm[4]];
  }
}

/// Do a quick line-level diff on both strings, then rediff the parts for greater accuracy.
///
/// This speedup can produce non-minimal diffs.
/// [text1] is the old string to be diffed.
/// [text2] is the new string to be diffed.
/// [deadline] is the time when the diff should be complete by.
/// Returns a List of Diff objects.
List<Diff> _diffLineMode(String text1, String text2, DateTime deadline) {
  // Scan the text on a line-by-line basis first.
  final a = diffLinesToChars(text1, text2);

  final linearray = a['lineArray'] as List<String>;
  text1 = a['chars1'] as String;
  text2 = a['chars2'] as String;

  final diffs = diffMain(
    text1,
    text2,
    checklines: false,
    deadline: deadline,
  );

  // Convert the diff back to original text.
  diffCharsToLines(diffs, linearray);
  // Eliminate freak matches (e.g. blank lines)
  diffCleanupSemantic(diffs);

  // Rediff any replacement blocks, this time character-by-character.
  // Add a dummy entry at the end.
  diffs.add(Diff(Operation.equal, ''));
  var pointer = 0;
  var countDelete = 0;
  var countInsert = 0;

  final textDelete = StringBuffer();
  final textInsert = StringBuffer();

  while (pointer < diffs.length) {
    switch (diffs[pointer].operation) {
      case Operation.insert:
        countInsert++;
        textInsert.write(diffs[pointer].text);
        break;

      case Operation.delete:
        countDelete++;
        textDelete.write(diffs[pointer].text);
        break;

      case Operation.equal:
        // Upon reaching an equality, check for prior redundancies.
        if (countDelete >= 1 && countInsert >= 1) {
          // Delete the offending records and add the merged ones.
          diffs.removeRange(pointer - countDelete - countInsert, pointer);
          pointer = pointer - countDelete - countInsert;

          final subDiff = diffMain(
            textDelete.toString(),
            textInsert.toString(),
            checklines: false,
            deadline: deadline,
          );

          for (var j = subDiff.length - 1; j >= 0; j--) {
            diffs.insert(pointer, subDiff[j]);
          }
          pointer = pointer + subDiff.length;
        }

        countInsert = 0;
        countDelete = 0;
        textDelete.clear();
        textInsert.clear();
        break;
    }
    pointer++;
  }
  diffs.removeLast(); // Remove the dummy entry at the end.

  return diffs;
}

/// Find the 'middle snake' of a diff, split the problem in two
/// and return the recursively constructed diff.
///
/// See [Myers 1986 paper][1]: An O(ND) Difference Algorithm and Its Variations.
/// [text1] is the old string to be diffed.
/// [text2] is the new string to be diffed.
/// [deadline] is the time at which to bail if not yet complete.
/// Returns a List of Diff objects.
///
/// [1]: https://neil.fraser.name/writing/diff/myers.pdf
@visibleForTesting
List<Diff> diffBisect(String text1, String text2, DateTime deadline) {
  // Cache the text lengths to prevent multiple calls.
  final text1Length = text1.length;
  final text2Length = text2.length;
  final maxD = (text1Length + text2Length + 1) ~/ 2;
  final vOffset = maxD;
  final vLength = 2 * maxD;
  final v1 = List<int>.filled(vLength, 0);
  final v2 = List<int>.filled(vLength, 0);

  for (var x = 0; x < vLength; x++) {
    v1[x] = -1;
    v2[x] = -1;
  }
  v1[vOffset + 1] = 0;
  v2[vOffset + 1] = 0;
  final delta = text1Length - text2Length;
  // If the total number of characters is odd, then the front path will
  // collide with the reverse path.
  final front = (delta % 2 != 0);
  // Offsets for start and end of k loop.
  // Prevents mapping of space beyond the grid.
  var k1start = 0;
  var k1end = 0;
  var k2start = 0;
  var k2end = 0;

  for (var d = 0; d < maxD; d++) {
    // Bail out if deadline is reached.
    if ((DateTime.now()).compareTo(deadline) == 1) {
      break;
    }

    // Walk the front path one step.
    for (var k1 = -d + k1start; k1 <= d - k1end; k1 += 2) {
      var k1Offset = vOffset + k1;
      int x1;

      if (k1 == -d || k1 != d && v1[k1Offset - 1] < v1[k1Offset + 1]) {
        x1 = v1[k1Offset + 1];
      } else {
        x1 = v1[k1Offset - 1] + 1;
      }

      var y1 = x1 - k1;
      while (x1 < text1Length && y1 < text2Length && text1[x1] == text2[y1]) {
        x1++;
        y1++;
      }

      v1[k1Offset] = x1;
      if (x1 > text1Length) {
        // Ran off the right of the graph.
        k1end += 2;
      } else if (y1 > text2Length) {
        // Ran off the bottom of the graph.
        k1start += 2;
      } else if (front) {
        var k2Offset = vOffset + delta - k1;
        if (k2Offset >= 0 && k2Offset < vLength && v2[k2Offset] != -1) {
          // Mirror x2 onto top-left coordinate system.
          var x2 = text1Length - v2[k2Offset];
          if (x1 >= x2) {
            // Overlap detected.
            return _diffBisectSplit(text1, text2, x1, y1, deadline);
          }
        }
      }
    }

    // Walk the reverse path one step.
    for (var k2 = -d + k2start; k2 <= d - k2end; k2 += 2) {
      var k2Offset = vOffset + k2;
      int x2;

      if (k2 == -d || k2 != d && v2[k2Offset - 1] < v2[k2Offset + 1]) {
        x2 = v2[k2Offset + 1];
      } else {
        x2 = v2[k2Offset - 1] + 1;
      }

      var y2 = x2 - k2;
      while (x2 < text1Length &&
          y2 < text2Length &&
          text1[text1Length - x2 - 1] == text2[text2Length - y2 - 1]) {
        x2++;
        y2++;
      }

      v2[k2Offset] = x2;
      if (x2 > text1Length) {
        // Ran off the left of the graph.
        k2end += 2;
      } else if (y2 > text2Length) {
        // Ran off the top of the graph.
        k2start += 2;
      } else if (!front) {
        var k1Offset = vOffset + delta - k2;
        if (k1Offset >= 0 && k1Offset < vLength && v1[k1Offset] != -1) {
          var x1 = v1[k1Offset];
          var y1 = vOffset + x1 - k1Offset;
          // Mirror x2 onto top-left coordinate system.
          x2 = text1Length - x2;
          if (x1 >= x2) {
            // Overlap detected.
            return _diffBisectSplit(text1, text2, x1, y1, deadline);
          }
        }
      }
    }
  }

  // Diff took too long and hit the deadline or
  // number of diffs equals number of characters, no commonality at all.
  return [Diff(Operation.delete, text1), Diff(Operation.insert, text2)];
}

/// Does a substring of shorttext exist within longtext such that the
/// substring is at least half the length of longtext?
///
/// [longtext] is the longer string. [shorttext] is the shorter string.
/// [i] Start index of quarter length substring within longtext.
/// Returns a five element String array, containing the prefix of longtext,
/// the suffix of longtext, the prefix of shorttext, the suffix of
/// shorttext and the common middle.  Or null if there was no match.
List<String>? _diffHalfMatchI(String longtext, String shorttext, int i) {
  // Start with a 1/4 length substring at position i as a seed.
  final seed = longtext.substring(i, i + (longtext.length / 4).floor().toInt());
  var j = -1;
  var bestCommon = '';
  var bestLongtextA = '', bestLongtextB = '';
  var bestShortTextA = '', bestShortTextB = '';

  while ((j = shorttext.indexOf(seed, j + 1)) != -1) {
    final prefixLength = diffCommonPrefix(
      longtext.substring(i),
      shorttext.substring(j),
    );

    final suffixLength = diffCommonSuffix(
      longtext.substring(0, i),
      shorttext.substring(0, j),
    );

    if (bestCommon.length < suffixLength + prefixLength) {
      bestCommon = shorttext.substring(j - suffixLength, j) +
          shorttext.substring(j, j + prefixLength);
      bestLongtextA = longtext.substring(0, i - suffixLength);
      bestLongtextB = longtext.substring(i + prefixLength);
      bestShortTextA = shorttext.substring(0, j - suffixLength);
      bestShortTextB = shorttext.substring(j + prefixLength);
    }
  }

  if (bestCommon.length * 2 >= longtext.length) {
    return [
      bestLongtextA,
      bestLongtextB,
      bestShortTextA,
      bestShortTextB,
      bestCommon
    ];
  } else {
    return null;
  }
}

/// Rehydrate the text in a diff from a string of line hashes to real lines of text.
///
/// [diffs] is a List of Diff objects.
/// [lineArray] is a List of unique strings.
@visibleForTesting
void diffCharsToLines(List<Diff> diffs, List<String>? lineArray) {
  final text = StringBuffer();

  for (var diff in diffs) {
    for (var j = 0; j < diff.text.length; j++) {
      text.write(lineArray![diff.text.codeUnitAt(j)]);
    }
    diff.text = text.toString();
    text.clear();
  }
}

/// Given the location of the 'middle snake', split the diff in two parts
/// and recurse.
///
/// [text1] is the old string to be diffed.
/// [text2] is the new string to be diffed.
/// [x] is the index of split point in text1.
/// [y] is the index of split point in text2.
/// [deadline] is the time at which to bail if not yet complete.
/// Returns a List of Diff objects.
List<Diff> _diffBisectSplit(
  String text1,
  String text2,
  int x,
  int y,
  DateTime? deadline,
) {
  final text1a = text1.substring(0, x);
  final text2a = text2.substring(0, y);
  final text1b = text1.substring(x);
  final text2b = text2.substring(y);

  // Compute both diffs serially.
  final diffs = diffMain(
    text1a,
    text2a,
    checklines: false,
    deadline: deadline,
  );
  final diffsb = diffMain(
    text1b,
    text2b,
    checklines: false,
    deadline: deadline,
  );

  diffs.addAll(diffsb);
  return diffs;
}
