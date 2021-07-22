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

void testDetectRuns() {
  group('detectRuns test:', () {
    var matches = <MatchRange>[];
    var n = 3;
    var expected = <Range>[];

    _testDetectRuns(
      'Zero match case',
      matches,
      n,
      expected,
    );

    matches = [MatchRange(Range(0, 100), Range(0, 100), 100)];
    expected = [Range(0, 23)];

    _testDetectRuns(
      'Perfect match case',
      matches,
      n,
      expected,
    );

    matches = [
      MatchRange(Range(0, 40), Range(0, 40), 40),
      MatchRange(Range(60, 100), Range(60, 100), 40),
    ];
    expected = [Range(0, 3)];

    _testDetectRuns(
      'Minimum number of hits required in window to qualify as match',
      matches,
      n,
      expected,
    );

    expected = [];

    _testDetectRuns(
      'Increasing threshold from 0.8 to 0.9 disqualifies previous match',
      matches,
      n,
      expected,
      confidenceThreshold: 0.9,
    );

    matches = [
      MatchRange(Range(0, 10), Range(0, 10), 10),
      MatchRange(Range(20, 30), Range(20, 30), 10),
      MatchRange(Range(40, 60), Range(40, 60), 20),
      MatchRange(Range(65, 80), Range(65, 80), 15),
      MatchRange(Range(81, 89), Range(11, 19), 8),
      MatchRange(Range(92, 100), Range(32, 40), 8),
    ];
    expected = [];

    // Set number of license count = 80.
    // If confidence threshold = 0.8, minimum number of hits required in
    // a window of 80 lenght equals 80 * 0.8 = 64.
    // Though the total number hits in matches equal to 71 (> nor of target tokens)
    // no window has hits >= 64 and hence should return an empty list.
    _testDetectRuns(
      'No window has hits greater than or equal to target count',
      matches,
      n,
      expected,
      licenseTokenCount: 80,
    );

    // Detect multiple fragmented runs.
    // Changing license token count to 50 (subset length becomes 50).
    // Setting source range to (0, 0) will not effect the result as it is not considerd in detectRuns routine.
    matches = [
      MatchRange(Range(10, 35), Range(0, 0), 25),
      MatchRange(Range(75, 100), Range(0, 0), 25),
      MatchRange(Range(45, 60), Range(0, 0), 15),
      MatchRange(Range(64, 69), Range(0, 0), 5)
    ];

    expected = [Range(10, 13), Range(45, 53)];

    _testDetectRuns(
      'Multiple runs',
      matches,
      n,
      expected,
      licenseTokenCount: 50,
    );
  });
}

void _testDetectRuns(
  String name,
  List<MatchRange> matches,
  int n,
  List<Range> expected, {
  double confidenceThreshold = 0.8,
  int inputTokensCount = 100,
  int licenseTokenCount = 100,
}) {
  test(name, () {
    final actual = detectRuns(
      matches,
      confidenceThreshold,
      inputTokensCount,
      licenseTokenCount,
      n,
    );

    expect(actual.length, expected.length);

    for (var i = 0; i < actual.length; i++) {
      expect(actual[i].start, expected[i].start);
      expect(actual[i].end, expected[i].end);
    }
  });
}

void testFuseRanges() {
  group('test fuseRanges:', () {
    var matches = [
      MatchRange(Range(0, 100), Range(0, 100), 100),
    ];
    var runs = [Range(0, 23)];
    var expected = [
      MatchRange(Range(0, 100), Range(0, 100), 100),
    ];

    _testFuseRanges(
      'Perfect match',
      expected,
      matches,
      runs,
    );

    matches = [
      MatchRange(Range(0, 45), Range(0, 45), 45),
      MatchRange(Range(55, 90), Range(65, 100), 35),
    ];

    expected = [MatchRange(Range(0, 90), Range(0, 100), 80)];

    matches = [
      MatchRange(Range(0, 40), Range(10, 50), 40),
      MatchRange(Range(65, 68), Range(50, 83), 3),
    ];
    expected = [
      MatchRange(Range(0, 40), Range(10, 50), 40),
    ];

    _testFuseRanges(
      'Discard matchRange with very less number of tokens claimed',
      expected,
      matches,
      runs,
    );

    // Merge the ranges if offset differences are within the error margin.
    // errorMargin = size * (1 - threshold) = 100 * (1 - 0.8) = 20
    _testFuseRanges(
      'Merge range if within error margin',
      expected,
      matches,
      runs,
    );

    matches = [
      MatchRange(Range(0, 45), Range(0, 45), 45),
      MatchRange(Range(55, 78), Range(77, 100), 23),
    ];
    runs = [Range(0, 20)];
    expected = [
      MatchRange(Range(0, 45), Range(0, 45), 45),
    ];

    // Discard range if offset differences of input and known license not within error margin.
    _testFuseRanges(
      'Discard range if start offset difference not within error margin',
      expected,
      matches,
      runs,
    );

    // Do not fuse ranges if absolute difference of the differences of their
    // input and known start indexes is not within the error range.
    matches = [
      MatchRange(Range(0, 40), Range(10, 50), 40),
      MatchRange(Range(65, 100), Range(50, 85), 35),
    ];

    _testFuseRanges(
      'Does not fuse matchRanges',
      matches,
      matches,
      runs,
    );
  });
}

void _testFuseRanges(
  String name,
  List<MatchRange> expected,
  List<MatchRange> matches,
  List<Range> runs, {
  double confidence = 0.8,
  int targetSize = 100,
  int size = 100,
}) {
  test(name, () {
    final actual = fuseMatchedRanges(
      matches,
      confidence,
      size,
      runs,
      targetSize,
    );

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

LicenseWithNGrams _getLicense(String content, int granularity) {
  return LicenseWithNGrams.parse(License.parse('', content), granularity);
}

void main() {
  testTargetMatchRanges();
  testDetectRuns();
  testFuseRanges();
}

void mafin() {
  var matches = [
    MatchRange(Range(0, 40), Range(10, 50), 40),
    MatchRange(Range(55, 90), Range(65, 100), 35),
  ];
  var confidenceThreshold = 0.8;
  // var n = 3;
  var runs = [Range(0, 20)];
  final actual = fuseMatchedRanges(
    matches,
    confidenceThreshold,
    100,
    runs,
    100,
  );

  for (var i = 0; i < actual.length; i++) {
    print('${actual[i].input.start}, ${actual[i].input.end}');
  }
}
