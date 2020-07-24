// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.maintenance;

import 'dart:math';

import 'package:json_annotation/json_annotation.dart';

import 'model.dart';
import 'utils.dart';

final Duration _year = const Duration(days: 365);
final Duration _twoYears = _year * 2;

final List<String> changelogFileNames = textFileNameCandidates('changelog');

final List<String> readmeFileNames = textFileNameCandidates('readme');

@deprecated
final List<String> exampleReadmeFileNames = <String>[
  ...textFileNameCandidates('example/example'),
  ...textFileNameCandidates('example/readme'),
];

/// Returns the candidates in priority order to display under the 'Example' tab.
List<String> exampleFileCandidates(
  String package, {
  bool caseSensitive = false,
}) {
  return <String>[
    if (caseSensitive) ...textFileNameCandidates('example/EXAMPLE'),
    ...textFileNameCandidates('example/example'),
    'example/lib/main.dart',
    'example/main.dart',
    'example/lib/$package.dart',
    'example/$package.dart',
    'example/lib/${package}_example.dart',
    'example/${package}_example.dart',
    'example/lib/example.dart',
    'example/example.dart',
    if (caseSensitive) ...textFileNameCandidates('example/README'),
    ...textFileNameCandidates('example/readme'),
  ];
}

const String currentAnalysisOptionsFileName = 'analysis_options.yaml';
final List<String> analysisOptionsFiles = const [
  currentAnalysisOptionsFileName,
  '.analysis_options',
];

String firstFileFromNames(List<String> files, List<String> names,
    {bool caseSensitive = false}) {
  for (var name in names) {
    for (var file in files) {
      if (file == name) {
        return file;
      } else if (!caseSensitive && file.toLowerCase() == name) {
        return file;
      }
    }
  }
  return null;
}

Suggestion getAgeSuggestion(Duration age) {
  age ??= Duration.zero;

  if (age > _twoYears) {
    return Suggestion.warning(
        SuggestionCode.packageVersionObsolete,
        'Package is too old.',
        'The package was last published more than two years ago.',
        score: 100.0);
  }

  // adjust score to the age
  if (age > _year) {
    final ageInWeeks = age.inDays ~/ 7;
    final daysOverAYear = age.inDays - _year.inDays;
    final score = max(0.0, min(100.0, daysOverAYear * 100.0 / 365));
    return Suggestion.hint(
        SuggestionCode.packageVersionOld,
        'Package is getting outdated.',
        'The package was last published $ageInWeeks weeks ago.',
        score: score);
  }

  return null;
}

/// Returns a markdown-formatted error message for pubspec.yaml parse error.
String pubspecParseError(error) {
  // TODO: remove this after json_annotation is updated with CheckedFromJsonException.toString()
  var message = error?.toString();
  if (error is CheckedFromJsonException) {
    final msg =
        error.message ?? 'Error with `${error.key}`: ${error.innerError}';
    message = 'CheckedFromJsonException: $msg';
  }
  return 'Error while parsing `pubspec.yaml`.\n\n'
      'Parsing throws an exception:\n\n```\n$message\n```';
}
