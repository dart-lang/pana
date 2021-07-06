// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

import 'crc32.dart';

@sealed
class License {
  /// Name of the license, is empty in case of unknown license.
  final String licenseName;

  /// Original text from the license file.
  final String content;

  /// Normalized [Token]s created from the original text.
  final List<Token> tokens;

  /// A map of tokens and their count.
  final Map<String, int> occurences;

  License._(this.content, this.tokens, this.occurences, this.licenseName);

  factory License.parse(String licenseName, String content) {
    final tokens = tokenize(content);
    final table = generateFrequencyTable(tokens);
    return License._(content, tokens, table, licenseName);
  }
}

@sealed
class Trigram {
  /// Text for which the hash value was generated.
  final String text;

  /// [Crc-32][1] checksum value generated for text.
  ///
  /// [1]: https://en.wikipedia.org/wiki/Cyclic_redundancy_check
  final int crc32;

  /// Index of the first token in the checskum.
  final int start;

  /// Index of the last token in the checksum.
  final int end;

  Trigram(this.text, this.crc32, this.start, this.end);
}

@sealed
class PossibleLicense {
  final License license;

  final List<Trigram> trigrams;

  final Map<int, List<Trigram>> checksumMap;

  PossibleLicense._(this.license, this.trigrams, this.checksumMap);

  factory PossibleLicense.parse(License license) {
    final checksums = generateChecksums(license.tokens);
    final table = generateChecksumMap(checksums);
    return PossibleLicense._(license, checksums, table);
  }
}

/// Contains deatils regarding the results of corpus license match with unknwown text.
@sealed
class LicenseMatch {
  /// Name of the license detected from unknown text.
  final String name;

  /// Tokens that were found in the unknown text that matched to tokens
  /// in any of the corpus license.
  final List<Token> tokens;

  /// Confidence score of the detected license.
  final double confidenceScore;

  /// SPDX license which matched with input.
  final License license;

  LicenseMatch(this.name, this.tokens, this.confidenceScore, this.license);
}

/// Genearates a frequency table for the give list of tokens.
@visibleForTesting
Map<String, int> generateFrequencyTable(List<Token> tokens) {
  var table = <String, int>{};

  for (var token in tokens) {
    table[token.value] = table.putIfAbsent(token.value, () => 0) + 1;
  }

  return table;
}

/// Creates [License] instances for all the corpus licenses.
List<License> loadLicensesFromDirectories(List<String> directories) {
  var licenses = <License>[];
  final length = directories.length;

  for (var i = 0; i < length; i++) {
    final dir = Directory(directories[i]);

    dir.listSync(recursive: false).forEach((element) {
      final license = getLicense(element.path);
      licenses.addAll(license);
    });
  }

  return List.unmodifiable(licenses);
}

Map<int, List<Trigram>> generateChecksumMap(List<Trigram> checksums) {
  var table = <int, List<Trigram>>{};
  for (var checksum in checksums) {
    table.putIfAbsent(checksum.crc32, () => []).add(checksum);
  }

  return table;
}

/// Returns [License] instance for the given license file.
@visibleForTesting
List<License> getLicense(String path) {
  var licenses = <License>[];
  final file = File(path);

  final fileName = file.uri.toString();
  if (!fileName.endsWith('.txt')) {
    return <License>[];
  }

  final name = file.uri.pathSegments.last.split('.txt').first;
  final content = file.readAsStringSync();
  licenses.add(License.parse(name, content));

  // If a license contains a optional part create and additional license
  // instance with the optional part of text removed to have
  // better chances of matching.
  if (_endOfTerms.hasMatch(content)) {
    final modifiedContent =
        content.replaceAll(_endOfTerms, 'END OF TERMS AND CONDITIONS');
    licenses.add(License.parse('${name}_NOEND', modifiedContent));
  }
  return licenses;
}

/// Generates crc-32 value for the given list of tokens
/// by taking 3 token values at a time.
List<Trigram> generateChecksums(List<Token> tokens) {
  final length = tokens.length - 2;
  if (tokens.length < 3) {
    final text = tokens.join(' ');
    return [Trigram(text, crc32(utf8.encode(text)), 0, tokens.length - 1)];
  }
  var checksums = <Trigram>[];

  for (var i = 0; i < length; i++) {
    final text =
        '${tokens[i].value} ${tokens[i + 1].value} ${tokens[i + 2].value}';
    final crcValue = crc32(utf8.encode(text));

    checksums.add(Trigram(text, crcValue, i, i + 2));
  }

  return checksums;
}

/// Regex to match the all the text starting from `END OF TERMS AND CONDTIONS`.
final _endOfTerms =
    RegExp(r'END OF TERMS AND CONDITIONS[\s\S]*', caseSensitive: false);
