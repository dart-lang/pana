part of 'diff.dart';

/// Determine the common prefix of two strings.
///
/// [text1] is the first string. [text2] is the second string.
/// Returns the number of characters common to the start of each string.
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

/// Determine the common suffix of two strings.
///
/// [text1] is the first string. [text2] is the second string.
/// Returns the number of characters common to the end of each string.
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

/// Compute the Levenshtein distance; the number of inserted, deleted or
/// substituted characters.
/// [diffs] is a List of Diff objects.
/// Returns the number of changes.
int diffLevenshtein(List<Diff> diffs) {
  var levenshtein = 0;
  var insertions = 0;
  var deletions = 0;

  for (var aDiff in diffs) {
    switch (aDiff.operation) {
      case Operation.insert:
        insertions += aDiff.text.length;
        break;
      case Operation.delete:
        deletions += aDiff.text.length;
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

final nonAlphaNumericRegex = RegExp(r'[^a-zA-Z0-9]');
final whitespaceRegex = RegExp(r'\s');
final linebreakRegex = RegExp(r'[\r\n]');
final blanklineEndRegex = RegExp(r'\n\r?\n$');
final blanklineStartRegex = RegExp(r'^\r?\n\r?\n');
