// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license.dart';
import 'package:pana/src/license_detection/token_matcher.dart';
import 'package:test/test.dart';

void testTargetMatchRanges() {
  group('targetMatchRanges test:', () {
    var unknownText = '';
    var knownText = 'a b c';
    var expected = <MatchRange>[];
    var granularity = 3;

    _testTargetMatchRanges(
      testDescription: 'Empty unknown text',
      unknownText: unknownText,
      knownText: knownText,
      expected: expected,
      granularity: granularity,
    );

    _testTargetMatchRanges(
      testDescription: 'Empty known text',
      unknownText: unknownText,
      knownText: knownText,
      expected: expected,
      granularity: granularity,
    );

    unknownText = '3 words match only';
    knownText = 'next 3 words match';
    expected = [MatchRange(Range(0, 3), Range(1, 4), 3)];

    _testTargetMatchRanges(
      testDescription: 'Basic match',
      unknownText: unknownText,
      knownText: knownText,
      expected: expected,
      granularity: granularity,
    );

    granularity = 4;
    expected = [];

    _testTargetMatchRanges(
      testDescription: 'Changing granularity prevents previous match',
      unknownText: unknownText,
      knownText: knownText,
      expected: expected,
      granularity: granularity,
    );

    unknownText = 'a b c d e f g h A B p q r P Q u v w x y';
    knownText = 'a b c d e f g h p q r A B u v w x y z';
    expected = [
      MatchRange(Range(0, 8), Range(0, 8), 8),
      MatchRange(Range(15, 20), Range(13, 18), 5),
      MatchRange(Range(10, 13), Range(8, 11), 3),
    ];
    granularity = 3;

    _testTargetMatchRanges(
      testDescription:
          'Detects all trigram matches and extend range on continuous matches',
      unknownText: unknownText,
      knownText: knownText,
      expected: expected,
      granularity: granularity,
    );

    granularity = 4;
    expected = [
      MatchRange(Range(0, 8), Range(0, 8), 8),
      MatchRange(Range(15, 20), Range(13, 18), 5),
    ];

    _testTargetMatchRanges(
      testDescription: 'Match with only 3 tokens claimed discarded',
      unknownText: unknownText,
      knownText: knownText,
      expected: expected,
      granularity: granularity,
    );

    unknownText =
        'a b c 1 a b c d e f 2 a b c d e f g h i j k l m 3 a b c d e f g h i j k l m n o p q r s t u v w x y z';
    knownText = 'a b c d e f g h i j k l m n o p q r s t u v w x y z a b c';
    expected = [
      MatchRange(Range(25, 51), Range(0, 26), 26),
      MatchRange(Range(11, 24), Range(0, 13), 13),
      MatchRange(Range(4, 10), Range(0, 6), 6)
    ];

    _testTargetMatchRanges(
      testDescription: 'Match and extend repetitive and fragmented text',
      unknownText: unknownText,
      knownText: knownText,
      expected: expected,
      granularity: granularity,
    );

    granularity = 7;
    expected = [
      MatchRange(Range(25, 51), Range(0, 26), 26),
      MatchRange(Range(11, 24), Range(0, 13), 13),
    ];

    _testTargetMatchRanges(
      testDescription:
          'Minimum 7 tokens required in a sequence to be qualify as a match',
      unknownText: unknownText,
      knownText: knownText,
      expected: expected,
      granularity: granularity,
    );
  });
}

void main() {
  testTargetMatchRanges();
}

void _testTargetMatchRanges({
  required String testDescription,
  required String unknownText,
  required String knownText,
  required List<MatchRange> expected,
  required int granularity,
}) {
  test(testDescription, () {
    final unknownLicense = _getLicense(unknownText, granularity);
    final knownLicense = _getLicense(knownText, granularity);
    final actual =
        getTargetMatchedRanges(knownLicense, unknownLicense, granularity);

    testOutput(actual, expected);
  });
}

void testOutput(List<MatchRange> actual, List<MatchRange> expected) {
  expect(actual.length, expected.length);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].source.start, expected[i].source.start);
    expect(actual[i].source.end, expected[i].source.end);
    expect(actual[i].input.start, expected[i].input.start);
    expect(actual[i].input.end, expected[i].input.end);
    expect(actual[i].tokensClaimed, expected[i].tokensClaimed);
  }
}

PossibleLicense _getLicense(String content, int granularity) {
  return PossibleLicense.parse(License.parse('', content), granularity);
}
