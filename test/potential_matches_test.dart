// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license_detector.dart';
import 'package:test/test.dart';

void testTargetMatchRanges() {
  group('targetMatchRanges test:', () {
    _testTargetMatchRanges(
      testDescription: 'Empty unknown text',
      unknownText: '',
      knownText: 'a b c',
      expected: [],
      n: 3,
    );

    _testTargetMatchRanges(
      testDescription: 'Empty known text',
      unknownText: 'a b c',
      knownText: '',
      expected: [],
      n: 3,
    );

    _testTargetMatchRanges(
      testDescription: 'Basic match',
      unknownText: '3 words match only',
      knownText: 'next 3 words match',
      n: 3,
      expected: [MatchRange(Range(0, 3), Range(1, 4), 3)],
    );

    _testTargetMatchRanges(
      testDescription: 'Changing granularity prevents previous match',
      unknownText: '3 words match only',
      knownText: 'next 3 words match',
      expected: [],
      n: 4,
    );

    _testTargetMatchRanges(
      testDescription:
          'Detects all trigram matches and extend range on continuous matches',
      unknownText: 'a b c d e f g h A B p q r P Q u v w x y',
      knownText: 'a b c d e f g h p q r A B u v w x y z',
      n: 3,
      expected: [
        MatchRange(Range(0, 8), Range(0, 8), 8),
        MatchRange(Range(15, 20), Range(13, 18), 5),
        MatchRange(Range(10, 13), Range(8, 11), 3),
      ],
    );

    _testTargetMatchRanges(
      testDescription: 'Match with only 3 tokens claimed discarded',
      unknownText: 'a b c d e f g h A B p q r P Q u v w x y',
      knownText: 'a b c d e f g h p q r A B u v w x y z',
      n: 4,
      expected: [
        MatchRange(Range(0, 8), Range(0, 8), 8),
        MatchRange(Range(15, 20), Range(13, 18), 5),
      ],
    );

    _testTargetMatchRanges(
      testDescription: 'Match and extend repetitive and fragmented text',
      unknownText:
          'a b c 1 a b c d e f 2 a b c d e f g h i j k l m 3 a b c d e f g h i j k l m n o p q r s t u v w x y z',
      knownText: 'a b c d e f g h i j k l m n o p q r s t u v w x y z a b c',
      n: 4,
      expected: [
        MatchRange(Range(25, 51), Range(0, 26), 26),
        MatchRange(Range(11, 24), Range(0, 13), 13),
        MatchRange(Range(4, 10), Range(0, 6), 6)
      ],
    );

    _testTargetMatchRanges(
      testDescription:
          'Minimum 7 tokens required in a sequence to be qualify as a match',
      unknownText:
          'a b c 1 a b c d e f 2 a b c d e f g h i j k l m 3 a b c d e f g h i j k l m n o p q r s t u v w x y z',
      knownText: 'a b c d e f g h i j k l m n o p q r s t u v w x y z a b c',
      n: 7,
      expected: [
        MatchRange(Range(25, 51), Range(0, 26), 26),
        MatchRange(Range(11, 24), Range(0, 13), 13),
      ],
    );
  });
}

void _testTargetMatchRanges({
  required String testDescription,
  required String unknownText,
  required String knownText,
  required List<MatchRange> expected,
  required int n,
}) {
  test(testDescription, () {
    final unknownLicense = _getLicense(unknownText, n);
    final knownLicense = _getLicense(knownText, n);
    final actual = getTargetMatchedRanges(knownLicense, unknownLicense, n);

    _testOutput(actual, expected);
  });
}

void testDetectRuns() {
  group('detectRuns test:', () {
    _testDetectRuns(
      name: 'Zero match case',
      matches: [],
      expected: [],
    );

    _testDetectRuns(
      name: 'Perfect match case',
      expected: [Range(0, 23)],
      matches: [MatchRange(Range(0, 100), Range(0, 100), 100)],
    );

    _testDetectRuns(
      name: 'Minimum number of hits required in window to qualify as match',
      expected: [Range(0, 3)],
      matches: [
        MatchRange(Range(0, 40), Range(0, 40), 40),
        MatchRange(Range(60, 100), Range(60, 100), 40),
      ],
    );

    _testDetectRuns(
      name: 'Increasing threshold from 0.8 to 0.9 disqualifies previous match',
      expected: [],
      confidenceThreshold: 0.9,
      matches: [
        MatchRange(Range(0, 40), Range(0, 40), 40),
        MatchRange(Range(60, 100), Range(60, 100), 40),
      ],
    );

    // Set number of license count = 80.
    // If confidence threshold = 0.8, minimum number of hits required in
    // a window of 80 lenght equals 80 * 0.8 = 64.
    // Though the total number hits in matches equal to 71 (> nor of target tokens)
    // no window has hits >= 64 and hence should return an empty list.
    _testDetectRuns(
      name: 'No window has hits greater than or equal to target count',
      expected: [],
      licenseTokenCount: 80,
      matches: [
        MatchRange(Range(0, 10), Range(0, 10), 10),
        MatchRange(Range(20, 30), Range(20, 30), 10),
        MatchRange(Range(40, 60), Range(40, 60), 20),
        MatchRange(Range(65, 80), Range(65, 80), 15),
        MatchRange(Range(81, 89), Range(11, 19), 8),
        MatchRange(Range(92, 100), Range(32, 40), 8),
      ],
    );

    // Detect multiple fragmented runs.
    // Changing license token count to 50 (subset length becomes 50).
    // Setting source range to (0, 0) will not effect the result as it is not considerd in detectRuns routine.
    _testDetectRuns(
      name: 'Multiple runs',
      licenseTokenCount: 50,
      expected: [Range(10, 13), Range(45, 53)],
      matches: [
        MatchRange(Range(10, 35), Range(0, 0), 25),
        MatchRange(Range(75, 100), Range(0, 0), 25),
        MatchRange(Range(45, 60), Range(0, 0), 15),
        MatchRange(Range(64, 69), Range(0, 0), 5)
      ],
    );
  });
}

void _testDetectRuns({
  required String name,
  required List<MatchRange> matches,
  int n = 3,
  required List<Range> expected,
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
    _testFuseRanges(
      name: 'Perfect match',
      expected: [MatchRange(Range(0, 100), Range(0, 100), 100)],
      matches: [MatchRange(Range(0, 100), Range(0, 100), 100)],
      runs: [Range(0, 23)],
    );

    _testFuseRanges(
      name: 'Discard matchRange with less number of tokens claimed',
      expected: [MatchRange(Range(0, 90), Range(0, 100), 80)],
      matches: [
        MatchRange(Range(0, 45), Range(0, 45), 45),
        MatchRange(Range(55, 90), Range(65, 100), 35),
        MatchRange(Range(46, 50), Range(56, 60), 4)
      ],
      runs: [Range(0, 23)],
    );

    // Discard range if offset differences of input and known license not within error margin.
    _testFuseRanges(
      name: 'Discard range if start offset difference not within error margin',
      expected: [MatchRange(Range(0, 45), Range(0, 45), 45)],
      runs: [Range(0, 20)],
      matches: [
        MatchRange(Range(0, 45), Range(0, 45), 45),
        MatchRange(Range(55, 78), Range(77, 100), 23),
      ],
    );

    // Do not fuse ranges if absolute difference of the differences of their
    // input and known start indexes is not within the error range.
    _testFuseRanges(
      name: 'Does not fuse matchRanges',
      runs: [Range(0, 20)],
      expected: [
        MatchRange(Range(0, 40), Range(10, 50), 40),
        MatchRange(Range(65, 100), Range(50, 85), 35),
      ],
      matches: [
        MatchRange(Range(0, 40), Range(10, 50), 40),
        MatchRange(Range(65, 100), Range(50, 85), 35),
      ],
    );
  });
}

void _testFuseRanges({
  required String name,
  required List<MatchRange> expected,
  required List<MatchRange> matches,
  required List<Range> runs,
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

    _testOutput(actual, expected);
  });
}

void testPotentialMatches() {
  const perfect100 = '''
  1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 ''';

  const missingInitial20 = '''
  21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 ''';

  const missingLast20 = '''
  1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80''';

  const xAt10Interval = '''
  1 2 3 4 5 6 7 8 9 x 11 12 13 14 15 16 17 18 19 x 21 22 23 24 25 26 27 28 29 x 31 32 33 34 35 36 37 38 39 x 41 42 43 44 45 46 47 48 49 x 51 52 53 54 55 56 57 58 59 x 61 62 63 64 65 66 67 68 69 x 71 72 73 74 75 76 77 78 79 x 81 82 83 84 85 86 87 88 89 x 91 92 93 94 95 96 97 98 99 x''';

  const thirtyIntervalGap = '''
  1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 x x x x x x x x x x 91 92 93 94 95 96 97 98 99 100 x x x x x x x x x x x x x x x x x x x x''';

  group('Test potentialMatches:', () {
    _testPotentialMatches(
      name: 'Perfect Match',
      unknownText: perfect100,
      knownText: perfect100,
      expected: [
        MatchRange(Range(0, 100), Range(0, 100), 100),
      ],
    );

    // Finds a match as the number of tokens claimed is >= threshold number of tokens.
    // i.e threshold count = confidenceThreshold * corpus size
    //                     = 0.8 * 100
    //                     = 80
    _testPotentialMatches(
      name: 'Missing initial 20 tokens',
      unknownText: missingInitial20,
      knownText: perfect100,
      expected: [MatchRange(Range(0, 80), Range(20, 100), 80)],
    );

    _testPotentialMatches(
      name: 'Missing last 20 tokens',
      unknownText: missingLast20,
      knownText: perfect100,
      expected: [MatchRange(Range(0, 80), Range(0, 80), 80)],
    );
    // Changing confidenceThresold to 0.9 should not produce
    // a hit as we would need minimum of 90 tokens to be matched.
    _testPotentialMatches(
      name: 'No hits',
      unknownText: missingLast20,
      knownText: perfect100,
      expected: [],
      confidence: 0.9,
    );

    _testPotentialMatches(
      name: 'Expect a match',
      unknownText: xAt10Interval,
      knownText: perfect100,
      confidence: 0.9,
      expected: [MatchRange(Range(0, 99), Range(0, 99), 90)],
    );

    // Should expect any hits.
    // Though the offset difference(unknownStart - knownStart) is 19 abs(72 - 91)
    // is less tham error margin(100 * (1 - 0.8)), it's contribution i.e 10
    // is still lesser than than the error it introduces.
    _testPotentialMatches(
      name: 'No hits, error introduced greather than contribution',
      unknownText: thirtyIntervalGap,
      knownText: perfect100,
      expected: [],
    );
  });
}

void _testPotentialMatches({
  required String name,
  required String unknownText,
  required String knownText,
  required List<MatchRange> expected,
  double confidence = 0.8,
  int n = 3,
}) {
  test(name, () {
    final unknownLicense = _getLicense(unknownText, n);
    final knownLicense = _getLicense(knownText, n);

    final actual =
        findPotentialMatches(unknownLicense, knownLicense, confidence);

    _testOutput(actual, expected);
  });
}

void _testOutput(List<MatchRange> actual, List<MatchRange> expected) {
  expect(actual.length, expected.length);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].source.start, expected[i].source.start);
    expect(actual[i].source.end, expected[i].source.end);
    expect(actual[i].input.start, expected[i].input.start);
    expect(actual[i].input.end, expected[i].input.end);
    expect(actual[i].tokensClaimed, expected[i].tokensClaimed);
  }
}

LicenseWithNGrams _getLicense(String content, int n) {
  return LicenseWithNGrams.parse(
      License.parse(identifier: '', content: content), n);
}

void main() {
  testTargetMatchRanges();
  testDetectRuns();
  testFuseRanges();
  testPotentialMatches();
}
