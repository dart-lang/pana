// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/maintenance.dart';
import 'package:test/test.dart';

void main() {
  group('Age-based suggestion', () {
    test('young package', () {
      expect(getAgeSuggestion(const Duration(days: 10)), isNull);
    });

    test('age: one and half years', () {
      final suggestion = getAgeSuggestion(const Duration(days: 555));
      expect(suggestion, isNotNull);
      expect(suggestion.title, 'Package is getting outdated.');
      expect(suggestion.level, 'hint');
      expect(suggestion.score, closeTo(52.05, 0.01));
    });

    test('age: two and half years', () {
      final suggestion = getAgeSuggestion(const Duration(days: 910));
      expect(suggestion, isNotNull);
      expect(suggestion.title, 'Package is too old.');
      expect(suggestion.level, 'warning');
      expect(suggestion.score, 100.0);
    });
  });
}
