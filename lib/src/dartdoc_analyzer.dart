// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'model.dart';
import 'sdk_env.dart';

List<Suggestion> getDartdocSuggestions(DartdocResult result) {
  if (result == null) {
    return null;
  }

  final suggestions = <Suggestion>[];

  if (!result.wasSuccessful) {
    suggestions.add(getDartdocRunFailedSuggestion(result));
  }

  return suggestions.isEmpty ? null : suggestions;
}

Suggestion getDartdocRunFailedSuggestion([DartdocResult result]) {
  final errorMessage = result?.processResult?.stderr?.toString() ?? '';
  return Suggestion.error(
    SuggestionCode.dartdocAborted,
    "Make sure `dartdoc` successfully runs on your package's source files.",
    'Running `dartdoc` failed with the following output:\n\n```\n$errorMessage\n```\n',
    score: 10.0,
  );
}
