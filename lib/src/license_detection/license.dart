// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/src/third_party/diff_match_patch/diff.dart';
import 'package:pana/src/license_detection/token_matcher.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

import 'crc32.dart';

@sealed
class License {
  /// SPDX identifier of the license, is empty in case of unknown license.
  final String identifier;

  /// Original text from the license file.
  final String content;

  /// Normalized [Token]s created from the original text.
  final List<Token> tokens;

  /// Map from [Token.value] to their number of occurrences in this license.
  final Map<String, int> occurrences;

  License._(this.content, this.tokens, this.occurrences, this.identifier);

  factory License.parse(String identifier, String content) {
    final tokens = tokenize(content);
    final table = generateFrequencyTable(tokens);
    return License._(content, tokens, table, identifier);
  }
}

String tokensNormalizedValue(Iterable<Token> tokens) {
  return tokens.map((token) => token.value).join(' ');
}

@sealed
class NGram {
  /// Text for which the hash value was generated.
  final String text;

  /// [CRC-32][1] checksum value generated for text.
  ///
  /// [1]: https://en.wikipedia.org/wiki/Cyclic_redundancy_check
  final int checksum;

  /// Index of the first token in the checksum.
  final int start;

  /// Index of the last token in the checksum.
  final int end;

  int get granularity => text.split(' ').length;

  NGram(this.text, this.checksum, this.start, this.end);
}

/// A [License] instance with generated [nGrams].
// TODO: Change class name to something more meaningful.
@sealed
class LicenseWithNGrams extends License {
  final List<NGram> nGrams;

  final Map<int, List<NGram>> checksumMap;

  final int n;

  LicenseWithNGrams._(
    this.nGrams,
    this.checksumMap,
    this.n,
    String identifier,
    String content,
    List<Token> tokens,
    Map<String, int> table,
  ) : super._(
          content,
          tokens,
          table,
          identifier,
        );

  factory LicenseWithNGrams.parse(License license, int n) {
    final nGrams = generateChecksums(license.tokens, n);
    final table = generateChecksumMap(nGrams);
    return LicenseWithNGrams._(
      nGrams,
      table,
      license.tokens.length < n ? license.tokens.length : n,
      license.identifier,
      license.content,
      license.tokens,
      license.occurrences,
    );
  }
}

/// Contains details regarding the results of corpus license match with unknown text.
@sealed
class LicenseMatch {
  /// Sequence of tokens from input text that were considered a match for the detected [License].
  final List<Token> tokens;

  /// [Diff]s calculated between target tokens and [license] tokens.
  final List<Diff> diffs;

  /// Range of [diffs] which represents the diffs between known license and unknown license.
  ///
  /// Diffs lying outside of [diffRange] represent the text in unknown license
  /// that is not a part of the [license](source) text.
  final Range diffRange;

  /// Confidence score of the detected license.
  final double confidence;

  /// Detected license the input have been found to match with given [confidence].
  final LicenseWithNGrams license;

  LicenseMatch(
    this.tokens,
    this.confidence,
    this.license,
    this.diffs,
    this.diffRange,
  );
}

/// Generates a frequency table for the given list of [tokens].
///
/// [Token.value] is mapped to the number of occurrences in the license text.
@visibleForTesting
Map<String, int> generateFrequencyTable(List<Token> tokens) {
  var table = <String, int>{};

  for (var token in tokens) {
    table[token.value] = table.putIfAbsent(token.value, () => 0) + 1;
  }

  return table;
}

/// Load a list of [License] from the license files in [directories].
///
/// The license files in [directories] are expected to be plain `.txt` with
/// proper `utf-8` encoding. Name of the license file is expected
/// to be in the form of [`<spdx-identifier>.txt`][1].
/// The [directories] are not searched recursively.
///
/// Throws if any of the [directories] contains a file not meeting the above criteria's.
///
/// [1]: https://spdx.dev/ids/
List<License> loadLicensesFromDirectories(Iterable<String> directories) {
  var licenses = <License>[];

  for (var dir in directories) {
    Directory(dir).listSync(recursive: false).forEach((file) {
      if (file.path.endsWith('.txt')) {
        final license = licensesFromFile(file.path);
        licenses.addAll(license);
      } else {
        throw FormatException(
            'Invalid file type:\nExpected: "spdx-identifier" Actual: ${file.uri.pathSegments.last}');
      }
    });
  }

  return List.unmodifiable(licenses);
}

/// Returns a list of [License] from the given license file.
///
/// If license text contains the phrase `END OF TERMS AND CONDITIONS`
/// which indicates the presence of optional text, two instances
/// of [License] are returned.
///
/// Throws if file is not properly encoded or name of the file is an
/// invalid [SPDX identifier][1].
///
/// [1]: https://github.com/spdx/license-list-XML/blob/master/DOCS/license-fields.md#explanation-of-spdx-license-list-fields
@visibleForTesting
List<License> licensesFromFile(String path) {
  var licenses = <License>[];
  final file = File(path);

  final rawContent = file.readAsBytesSync();
  final identifier = file.uri.pathSegments.last.split('.txt').first;

  if (_invalidIdentifier.hasMatch(identifier)) {
    throw ArgumentError(
        'Invalid file name: expected: "path/to/file/<spdx-identifier>.txt" actual: $path');
  }
  var content = '';

  try {
    content = utf8.decode(rawContent);
  } on FormatException {
    throw ArgumentError('Invalid utf-8 encoding: $path');
  }

  licenses.add(License.parse(identifier, content));

  // If a license contains a optional part create an additional license
  // instance with the optional part of text removed to have
  // better chances of matching.
  if (content.contains(_endOfTerms)) {
    final modifiedContent = content.split(_endOfTerms).first + _endOfTerms;
    licenses.add(License.parse(identifier, modifiedContent));
  }
  return licenses;
}

/// Regex to match the all the text starting from `END OF TERMS AND CONDTIONS`.
const _endOfTerms = 'END OF TERMS AND CONDITIONS';

/// Generates crc-32 checksum for the given list of tokens
/// by taking [granularity] token values at a time.
List<NGram> generateChecksums(List<Token> tokens, int granularity) {
  if (tokens.length < granularity) {
    final text = tokens.join(' ');
    return [NGram(text, crc32(utf8.encode(text)), 0, tokens.length - 1)];
  }

  var nGrams = <NGram>[];

  for (var i = 0; i + granularity <= tokens.length; i++) {
    var text = '';
    tokens.skip(i).take(granularity).forEach((token) {
      text += token.value + ' ';
    });

    final crcValue = crc32(utf8.encode(text));

    nGrams.add(NGram(text, crcValue, i, i + granularity));
  }

  return nGrams;
}

/// Generates a frequency table for the given list of [nGrams].
///
/// [NGram.checksum] is mapped to a list of NGrams having the same
/// checksum value.
Map<int, List<NGram>> generateChecksumMap(List<NGram> nGrams) {
  var table = <int, List<NGram>>{};
  for (var checksum in nGrams) {
    table.putIfAbsent(checksum.checksum, () => []).add(checksum);
  }

  return table;
}

/// Identifier not following the norms of  [SPDX short identifier][1]
/// is a invalid identifier.
///
/// [1]: https://github.com/spdx/license-list-XML/blob/master/DOCS/license-fields.md#explanation-of-spdx-license-list-fields
final _invalidIdentifier = RegExp(r'[^a-zA-Z\d\.\-\_+]');
