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
    suggestions.add(getDartdocRunFailedSuggestion());
  }

  return suggestions.isEmpty ? null : suggestions;
}

Suggestion getDartdocRunFailedSuggestion() {
  return Suggestion.error(
    SuggestionCode.dartdocAborted,
    'Running `dartdoc` failed.',
    'Make sure `dartdoc` runs without any issues.',
    score: 10.0,
  );
}
