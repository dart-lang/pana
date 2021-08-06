part of 'diff.dart';

/// Returns the number of characters common to the start of each string.
///
/// Determine the common prefix of two strings.
/// [text1] is the first string. [text2] is the second string.
@visibleForTesting
int diffCommonPrefix(String text1, String text2) {
  // TODO: Once Dart's performance stabilizes, determine if linear or binary
  // search is better.
  // Performance analysis: https://neil.fraser.name/news/2007/10/09/
  final n = min(text1.length, text2.length);

  for (var i = 0; i < n; i++) {
    if (text1[i] != text2[i]) {
      return i;
    }
  }
  return n;
}

/// Returns the number of characters common to the end of each string.
///
/// Determine the common suffix of two strings.
/// [text1] is the first string. [text2] is the second string.
@visibleForTesting
int diffCommonSuffix(String text1, String text2) {
  // TODO: Once Dart's performance stabilizes, determine if linear or binary
  // search is better.
  // Performance analysis: https://neil.fraser.name/news/2007/10/09/
  final text1Length = text1.length;
  final text2Length = text2.length;
  final n = min(text1Length, text2Length);

  for (var i = 1; i <= n; i++) {
    if (text1[text1Length - i] != text2[text2Length - i]) {
      return i - 1;
    }
  }
  return n;
}

/// Split a text into a list of strings. Reduce the texts to a string of
/// hashes where each Unicode character represents one line.
///
/// [text] is the string to encode.
/// [lineArray] is a List of unique strings.
/// [lineHash] is a Map of strings to indices.
/// [maxLines] is the maximum length for lineArray.
/// Returns an encoded string.
String _diffLinesToCharsMunge(
  String text,
  List<String> lineArray,
  Map<String, int> lineHash,
  int maxLines,
) {
  var lineStart = 0;
  var lineEnd = -1;
  String line;
  final chars = StringBuffer();

  // Walk the text, pulling out a substring for each line.
  // text.split('\n') would would temporarily double our memory footprint.
  // Modifying text would create many large strings to garbage collect.
  while (lineEnd < text.length - 1) {
    lineEnd = text.indexOf('\n', lineStart);

    if (lineEnd == -1) {
      lineEnd = text.length - 1;
    }
    line = text.substring(lineStart, lineEnd + 1);

    if (lineHash.containsKey(line)) {
      chars.writeCharCode(lineHash[line]!);
    } else {
      if (lineArray.length == maxLines) {
        // Bail out at 65535 because
        // final chars1 =  StringBuffer();
        // chars1.writeCharCode(65536);
        // chars1.toString().codeUnitAt(0) == 55296;
        line = text.substring(lineStart);
        lineEnd = text.length;
      }
      lineArray.add(line);
      lineHash[line] = lineArray.length - 1;
      chars.writeCharCode(lineArray.length - 1);
    }
    lineStart = lineEnd + 1;
  }
  return chars.toString();
}

/// Split two texts into a list of strings. Reduce the texts to a string of
/// hashes where each Unicode character represents one line.
///
/// [text1] is the first string.
/// [text2] is the second string.
/// Returns a Map containing the encoded text1, the encoded text2 and
/// the List of unique strings. The zeroth element of the List of
/// unique strings is intentionally blank.
@visibleForTesting
Map<String, dynamic> diffLinesToChars(String text1, String text2) {
  final lineArray = <String>[];
  final lineHash = HashMap<String, int>();
  // e.g. linearray[4] == 'Hello\n'
  // e.g. linehash['Hello\n'] == 4

  // '\x00' is a valid character, but various debuggers don't like it.
  // So we'll insert a junk entry to avoid generating a null character.
  lineArray.add('');

  // Allocate 2/3rds of the space for text1, the rest for text2.
  final chars1 = _diffLinesToCharsMunge(text1, lineArray, lineHash, 40000);
  final chars2 = _diffLinesToCharsMunge(text2, lineArray, lineHash, 65535);

  return {'chars1': chars1, 'chars2': chars2, 'lineArray': lineArray};
}

int diffLevenshteinWord(Iterable<Diff> diffs) {
  var levenshtein = 0;
  var insertions = 0;
  var deletions = 0;

  for (var aDiff in diffs) {
    switch (aDiff.operation) {
      case Operation.insert:
        insertions += _countWords(aDiff.text);
        break;
      case Operation.delete:
        deletions += _countWords(aDiff.text);
        break;
      case Operation.equal:
        // A deletion and an insertion is one substitution.
        levenshtein += max(insertions, deletions);
        insertions = 0;
        deletions = 0;
        break;
    }
  }

  levenshtein += max(insertions, deletions);
  return levenshtein;
}

int _countWords(String text) {
  if (text.isEmpty) {
    return 0;
  }

  return text.trimRight().split(' ').length;
}

@visibleForTesting
List<String> diffRebuildtexts(List<Diff> diffs) {
  // Construct the two texts which made up the diff originally.
  final text1 = StringBuffer();
  final text2 = StringBuffer();
  for (var x = 0; x < diffs.length; x++) {
    if (diffs[x].operation != Operation.insert) {
      text1.write(diffs[x].text);
    }
    if (diffs[x].operation != Operation.delete) {
      text2.write(diffs[x].text);
    }
  }
  return [text1.toString(), text2.toString()];
}

/// Determine if the suffix of one string is the prefix of another.
///
/// [text1] is the first string.
/// [text2] is the second string.
/// Returns the number of characters common to the end of the first
/// string and the start of the second string.
@visibleForTesting
int diffCommonOverlap(String text1, String text2) {
  // Eliminate the null case.
  if (text1.isEmpty || text2.isEmpty) {
    return 0;
  }

  // Cache the text lengths to prevent multiple calls.
  final text1Length = text1.length;
  final text2Length = text2.length;

  // Truncate the longer string.
  if (text1Length > text2Length) {
    text1 = text1.substring(text1Length - text2Length);
  } else if (text1Length < text2Length) {
    text2 = text2.substring(0, text1Length);
  }

  final textLength = min(text1Length, text2Length);
  // Quick check for the worst case.
  if (text1 == text2) {
    return textLength;
  }

  // Start by looking for a single character match
  // and increase length until no match is found.
  // Performance analysis: https://neil.fraser.name/news/2010/11/04/
  var best = 0;
  var length = 1;
  while (true) {
    var pattern = text1.substring(textLength - length);
    var found = text2.indexOf(pattern);
    if (found == -1) {
      return best;
    }
    length += found;
    if (found == 0 ||
        text1.substring(textLength - length) == text2.substring(0, length)) {
      best = length;
      length++;
    }
  }
}

/// Reduce the number of edits by eliminating operationally trivial equalities.
/// [diffs] is a List of Diff objects.
void diffCleanupEfficiency(List<Diff> diffs, {int diffEditCost = 4}) {
  var changes = false;
  // Stack of indices where equalities are found.
  final equalities = <int>[];
  // Always equal to diffs[equalities.last()].text
  String? lastEquality;
  var pointer = 0; // Index of current position.
  // Is there an insertion operation before the last equality.
  var preIns = false;
  // Is there a deletion operation before the last equality.
  var preDel = false;
  // Is there an insertion operation after the last equality.
  var postIns = false;
  // Is there a deletion operation after the last equality.
  var postDel = false;
  while (pointer < diffs.length) {
    if (diffs[pointer].operation == Operation.equal) {
      // Equality found.
      if (diffs[pointer].text.length < diffEditCost && (postIns || postDel)) {
        // Candidate found.
        equalities.add(pointer);
        preIns = postIns;
        preDel = postDel;
        lastEquality = diffs[pointer].text;
      } else {
        // Not a candidate, and can never become one.
        equalities.clear();
        lastEquality = null;
      }
      postIns = postDel = false;
    } else {
      // An insertion or deletion.
      if (diffs[pointer].operation == Operation.delete) {
        postDel = true;
      } else {
        postIns = true;
      }

      // Five types to be split:
      // <ins>A</ins><del>B</del>XY<ins>C</ins><del>D</del>
      // <ins>A</ins>X<ins>C</ins><del>D</del>
      // <ins>A</ins><del>B</del>X<ins>C</ins>
      // <ins>A</del>X<ins>C</ins><del>D</del>
      // <ins>A</ins><del>B</del>X<del>C</del>
      if (lastEquality != null &&
          ((preIns && preDel && postIns && postDel) ||
              ((lastEquality.length < diffEditCost / 2) &&
                  ((preIns ? 1 : 0) +
                          (preDel ? 1 : 0) +
                          (postIns ? 1 : 0) +
                          (postDel ? 1 : 0)) ==
                      3))) {
        // Duplicate record.
        diffs.insert(equalities.last, Diff(Operation.delete, lastEquality));
        // Change second copy to insert.
        diffs[equalities.last + 1].operation = Operation.insert;
        equalities.removeLast(); // Throw away the equality we just deleted.
        lastEquality = null;
        if (preIns && preDel) {
          // No changes made which could affect previous entry, keep going.
          postIns = postDel = true;
          equalities.clear();
        } else {
          if (equalities.isNotEmpty) {
            equalities.removeLast();
          }
          pointer = equalities.isEmpty ? -1 : equalities.last;
          postIns = postDel = false;
        }
        changes = true;
      }
    }
    pointer++;
  }

  if (changes) {
    diffCleanupMerge(diffs);
  }
}

/// Reduce the number of edits by eliminating semantically trivial equalities.
/// [diffs] is a List of Diff objects.
void diffCleanupSemantic(List<Diff> diffs) {
  final equalities = <int>[];

  var changes = false;

  // Stack of indices where equalities are found.
  // Always equal to diffs[equalities.last()].text
  String? lastEquality;

  // Index of current position.
  var pointer = 0;

  // Number of characters that changed prior to the equality.
  var lengthInsertions1 = 0;
  var lengthDeletions1 = 0;

  // Number of characters that changed after the equality.
  var lengthInsertions2 = 0;
  var lengthDeletions2 = 0;

  while (pointer < diffs.length) {
    if (diffs[pointer].operation == Operation.equal) {
      // Equality found.
      equalities.add(pointer);
      lengthInsertions1 = lengthInsertions2;
      lengthDeletions1 = lengthDeletions2;
      lengthInsertions2 = 0;
      lengthDeletions2 = 0;
      lastEquality = diffs[pointer].text;
    } else {
      // An insertion or deletion.
      if (diffs[pointer].operation == Operation.insert) {
        lengthInsertions2 += diffs[pointer].text.length;
      } else {
        lengthDeletions2 += diffs[pointer].text.length;
      }
      // Eliminate an equality that is smaller or equal to the edits on both
      // sides of it.
      if (lastEquality != null &&
          (lastEquality.length <= max(lengthInsertions1, lengthDeletions1)) &&
          (lastEquality.length <= max(lengthInsertions2, lengthDeletions2))) {
        // Duplicate record.
        diffs.insert(equalities.last, Diff(Operation.delete, lastEquality));

        // Change second copy to insert.
        diffs[equalities.last + 1].operation = Operation.insert;

        // Throw away the equality we just deleted.
        equalities.removeLast();

        // Throw away the previous equality (it needs to be revaluated).
        if (equalities.isNotEmpty) {
          equalities.removeLast();
        }

        pointer = equalities.isEmpty ? -1 : equalities.last;
        lengthInsertions1 = 0; // Reset the counters.
        lengthDeletions1 = 0;
        lengthInsertions2 = 0;
        lengthDeletions2 = 0;
        lastEquality = null;
        changes = true;
      }
    }
    pointer++;
  }

  // Normalize the diff.
  if (changes) {
    diffCleanupMerge(diffs);
  }
  diffCleanupSemanticLossless(diffs);

  // Find any overlaps between deletions and insertions.
  // e.g: <del>abcxxx</del><ins>xxxdef</ins>
  //   -> <del>abc</del>xxx<ins>def</ins>
  // e.g: <del>xxxabc</del><ins>defxxx</ins>
  //   -> <ins>def</ins>xxx<del>abc</del>
  // Only extract an overlap if it is as big as the edit ahead or behind it.
  pointer = 1;
  while (pointer < diffs.length) {
    if (diffs[pointer - 1].operation == Operation.delete &&
        diffs[pointer].operation == Operation.insert) {
      final deletion = diffs[pointer - 1].text;
      final insertion = diffs[pointer].text;
      final overlapLength1 = diffCommonOverlap(deletion, insertion);
      final overlapLength2 = diffCommonOverlap(insertion, deletion);

      if (overlapLength1 >= overlapLength2) {
        if (overlapLength1 >= deletion.length / 2 ||
            overlapLength1 >= insertion.length / 2) {
          // Overlap found.
          // Insert an equality and trim the surrounding edits.
          diffs.insert(
            pointer,
            Diff(Operation.equal, insertion.substring(0, overlapLength1)),
          );

          diffs[pointer - 1].text =
              deletion.substring(0, deletion.length - overlapLength1);

          diffs[pointer + 1].text = insertion.substring(overlapLength1);
          pointer++;
        }
      } else {
        if (overlapLength2 >= deletion.length / 2 ||
            overlapLength2 >= insertion.length / 2) {
          // Reverse overlap found.
          // Insert an equality and swap and trim the surrounding edits.
          diffs.insert(
            pointer,
            Diff(Operation.equal, deletion.substring(0, overlapLength2)),
          );

          diffs[pointer - 1] = Diff(Operation.insert,
              insertion.substring(0, insertion.length - overlapLength2));

          diffs[pointer + 1] =
              Diff(Operation.delete, deletion.substring(overlapLength2));
          pointer++;
        }
      }
      pointer++;
    }
    pointer++;
  }
}

/// Look for single edits surrounded on both sides by equalities
/// which can be shifted sideways to align the edit to a word boundary.
/// e.g: The c<ins>at c</ins>ame. -> The <ins>cat </ins>came.
/// [diffs] is a List of Diff objects.
void diffCleanupSemanticLossless(List<Diff> diffs) {
  /// Given two strings, compute a score representing whether the internal
  /// boundary falls on logical boundaries.
  /// Scores range from 6 (best) to 0 (worst).
  /// Closure, but does not reference any external variables.
  /// [one] the first string.
  /// [two] the second string.
  /// Returns the score.
  int _diffCleanupSemanticScore(String one, String two) {
    if (one.isEmpty || two.isEmpty) {
      // Edges are the best.
      return 6;
    }

    // Each port of this function behaves slightly differently due to
    // subtle differences in each language's definition of things like
    // 'whitespace'.  Since this function's purpose is largely cosmetic,
    // the choice has been made to use each language's native features
    // rather than force total conformity.
    final char1 = one[one.length - 1];
    final char2 = two[0];
    final nonAlphaNumeric1 = char1.contains(nonAlphaNumericRegex);
    final nonAlphaNumeric2 = char2.contains(nonAlphaNumericRegex);
    final whitespace1 = nonAlphaNumeric1 && char1.contains(whitespaceRegex);
    final whitespace2 = nonAlphaNumeric2 && char2.contains(whitespaceRegex);
    final lineBreak1 = whitespace1 && char1.contains(linebreakRegex);
    final lineBreak2 = whitespace2 && char2.contains(linebreakRegex);
    final blankLine1 = lineBreak1 && one.contains(blanklineEndRegex);
    final blankLine2 = lineBreak2 && two.contains(blanklineStartRegex);

    if (blankLine1 || blankLine2) {
      // Five points for blank lines.
      return 5;
    } else if (lineBreak1 || lineBreak2) {
      // Four points for line breaks.
      return 4;
    } else if (nonAlphaNumeric1 && !whitespace1 && whitespace2) {
      // Three points for end of sentences.
      return 3;
    } else if (whitespace1 || whitespace2) {
      // Two points for whitespace.
      return 2;
    } else if (nonAlphaNumeric1 || nonAlphaNumeric2) {
      // One point for non-alphanumeric.
      return 1;
    }
    return 0;
  }

  var pointer = 1;
  // Intentionally ignore the first and last element (don't need checking).
  while (pointer < diffs.length - 1) {
    if (diffs[pointer - 1].operation == Operation.equal &&
        diffs[pointer + 1].operation == Operation.equal) {
      // This is a single edit surrounded by equalities.
      var equality1 = diffs[pointer - 1].text;
      var edit = diffs[pointer].text;
      var equality2 = diffs[pointer + 1].text;

      // First, shift the edit as far left as possible.
      var commonOffset = diffCommonSuffix(equality1, edit);
      if (commonOffset != 0) {
        final commonString = edit.substring(edit.length - commonOffset);
        equality1 = equality1.substring(0, equality1.length - commonOffset);
        edit = commonString + edit.substring(0, edit.length - commonOffset);
        equality2 = commonString + equality2;
      }

      // Second, step character by character right, looking for the best fit.
      var bestEquality1 = equality1;
      var bestEdit = edit;
      var bestEquality2 = equality2;
      var bestScore = _diffCleanupSemanticScore(equality1, edit) +
          _diffCleanupSemanticScore(edit, equality2);

      while (
          edit.isNotEmpty && equality2.isNotEmpty && edit[0] == equality2[0]) {
        equality1 = equality1 + edit[0];
        edit = edit.substring(1) + equality2[0];
        equality2 = equality2.substring(1);

        final score = _diffCleanupSemanticScore(equality1, edit) +
            _diffCleanupSemanticScore(edit, equality2);

        // The >= encourages trailing rather than leading whitespace on edits.
        if (score >= bestScore) {
          bestScore = score;
          bestEquality1 = equality1;
          bestEdit = edit;
          bestEquality2 = equality2;
        }
      }

      if (diffs[pointer - 1].text != bestEquality1) {
        // We have an improvement, save it back to the diff.
        if (bestEquality1.isNotEmpty) {
          diffs[pointer - 1].text = bestEquality1;
        } else {
          diffs.removeAt(pointer - 1);
          pointer--;
        }
        diffs[pointer].text = bestEdit;
        if (bestEquality2.isNotEmpty) {
          diffs[pointer + 1].text = bestEquality2;
        } else {
          diffs.removeAt(pointer + 1);
          pointer--;
        }
      }
    }
    pointer++;
  }
}

final nonAlphaNumericRegex = RegExp(r'[^a-zA-Z0-9]');
final whitespaceRegex = RegExp(r'\s');
final linebreakRegex = RegExp(r'[\r\n]');
final blanklineEndRegex = RegExp(r'\n\r?\n$');
final blanklineStartRegex = RegExp(r'^\r?\n\r?\n');
