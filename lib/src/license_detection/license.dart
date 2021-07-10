// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

@sealed
class License {
  /// SPDX identifier of the license, is empty in case of unknown license.
  final String identifier;

  /// Original text from the license file.
  final String content;

  /// Normalized [Token]s created from the original text.
  final List<Token> tokens;

  /// Map from [Token.value] to their number of occurences in this license.
  final Map<String, int> occurrences;

  License._(this.content, this.tokens, this.occurrences, this.identifier);

  factory License.parse(String identifier, String content) {
    final tokens = tokenize(content);
    final table = generateFrequencyTable(tokens);
    return License._(content, tokens, table, identifier);
  }
}

/// Contains deatils regarding the results of corpus license match with unknwown text.
@sealed
class LicenseMatch {
  /// Sequence of tokens from input text that were considered a match for the detected [License].
  final List<Token> tokens;

  /// Confidence score of the detected license.
  final double confidence;

  /// Detected license the input have been found to match with given [confidence].
  final License license;

  LicenseMatch(this.tokens, this.confidence, this.license);
}

/// Generates a frequency table for the given list of [tokens].
///
/// [Token.value] is mapped to the number of occurences in the license text.
@visibleForTesting
Map<String, int> generateFrequencyTable(List<Token> tokens) {
  var table = <String, int>{};

  for (var token in tokens) {
    table[token.value] = table.putIfAbsent(token.value, () => 0) + 1;
  }

  return table;
}

/// Load a list of [License] from the license files found in [directories].
///
/// The files in [directories] should be plain `.txt` and `utf-8` encoded.
/// In case it is not `utf-8` encoded the file will be skipped.
/// Name of the license file is expected to be in the form of `spdx-identifier.txt`.
/// The [directories] are not searched recursively.
/// Throws [FormatException] if any of the directories contains a file that is not a valid license file.
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
/// Returns an empty list incase of bad file encoding.
/// If license text contains the phrase `END OF TERMS AND CONDITIONS`
/// which indicates the presence of optional text, two instances
/// of [License] are returned.
@visibleForTesting
List<License> licensesFromFile(String path) {
  var licenses = <License>[];
  final file = File(path);

  final rawContent = file.readAsBytesSync();

  var content = '';

  try {
    content = utf8.decode(rawContent);
  } on FormatException catch (_, e) {
    print('Format Exception: ${file.uri} \n${e.toString()} ');
    return [];
  }

  final identifier = file.uri.pathSegments.last.split('.txt').first;
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
