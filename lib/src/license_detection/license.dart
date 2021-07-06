// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

@sealed
class License {
  /// Name of the license, is empty in case of unknown license.
  final String identifier;

  /// Original text from the license file.
  final String content;

  /// Normalized [Token]s created from the original text.
  final List<Token> tokens;

  /// A map of tokens and their count.
  final Map<String, int> occurences;

  License._(this.content, this.tokens, this.occurences, this.identifier);

  factory License.parse(String identifier, String content) {
    final tokens = tokenize(content);
    final table = generateFrequencyTable(tokens);
    return License._(content, tokens, table, identifier);
  }
}

/// Contains deatils regarding the results of corpus license match with unknwown text.
@sealed
class LicenseMatch {
  /// Sequence of tokens that were found in the unknown
  ///  text that matched to tokens in any of the corpus license.
  final List<Token> tokens;

  /// Confidence score of the detected license.
  final double confidence;

  /// SPDX license which matched with input.
  final License license;

  LicenseMatch(this.tokens, this.confidence, this.license);
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
      final license = licenseFromFile(element.path);
      licenses.addAll(license);
    });
  }

  return List.unmodifiable(licenses);
}

/// Returns [License] instance for the given license file.
@visibleForTesting
List<License> licenseFromFile(String path) {
  var licenses = <License>[];
  final file = File(path);

  final fileName = file.uri.toString();
  if (!fileName.endsWith('.txt')) {
    return <License>[];
  }

  final identifier = file.uri.pathSegments.last.split('.txt').first;
  final content = file.readAsStringSync();
  licenses.add(License.parse(identifier, content));

  // If a license contains a optional part create and additional license
  // instance with the optional part of text removed to have
  // better chances of matching.
  if (content.contains(_endOfTerms)) {
    final modifiedContent = content.split(_endOfTerms).first + _endOfTerms;
    licenses.add(License.parse(identifier, modifiedContent));
  }
  return licenses;
}

/// Regex to match the all the text starting from `END OF TERMS AND CONDTIONS`.
final _endOfTerms = 'END OF TERMS AND CONDITIONS';
