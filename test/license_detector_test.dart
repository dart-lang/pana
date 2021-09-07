import 'package:pana/src/license_detection/license_detector.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('computeGranularity test:', () {
    test('Expect grnularity 3', () {
      expect(computeGranularity(0.75), 3);
    });

    test('Expect granularity 10', () {
      expect(computeGranularity(0.95), 10);
    });
  });

  group('sortOnConfidence Tests', () {
    test('Expect -1 for confidence of A greater than B', () {
      final matchA = _dummyLicenseMatchInstance(0.9, 'matchA');
      final matchB = _dummyLicenseMatchInstance(0.8, 'matchB');

      expect(sortOnConfidence(matchA, matchB), -1);
    });

    test('Expect 1 for confidence of matchA lesser than matchB', () {
      final matchA = _dummyLicenseMatchInstance(0.5, 'matchA');
      final matchB = _dummyLicenseMatchInstance(1, 'matchB');

      expect(sortOnConfidence(matchA, matchB), 1);
    });

    test('Check token density when both have same matches', () {
      final matchA =
          _dummyLicenseMatchInstance(0.9, 'matchA', tokensClaimed: 1);
      final matchB =
          _dummyLicenseMatchInstance(0.9, 'matchB', tokensClaimed: 2);

      // Expect -1 as matchA has more number of tokens claimed and both the matches
      // have same instance of license detected.
      expect(sortOnConfidence(matchA, matchB), 1);
    });
  });
  group('removeDuplicateMatches tests: ', () {
    test('No duplicates present', () {
      final matches = [
        _dummyLicenseMatchInstance(0.95, 'matchA'),
        _dummyLicenseMatchInstance(0.9, 'matchB'),
      ];

      final expected = [
        _dummyLicenseMatchInstance(0.95, 'matchA'),
        _dummyLicenseMatchInstance(0.9, 'matchB'),
      ];

      final actual = removeDuplicates(matches);

      _testOutput(actual, expected);
    });
    test('duplicates present', () {
      final matches = [
        _dummyLicenseMatchInstance(0.95, 'matchA'),
        _dummyLicenseMatchInstance(0.9, 'matchB'),
        _dummyLicenseMatchInstance(0.8, 'matchA'),
        _dummyLicenseMatchInstance(0.75, 'matchB'),
      ];

      final expected = [
        _dummyLicenseMatchInstance(0.95, 'matchA'),
        _dummyLicenseMatchInstance(0.9, 'matchB'),
      ];

      final actual = removeDuplicates(matches);

      _testOutput(actual, expected);
    });
  });

  group('removeoverLappingMatches tests:', () {
    _testOverLappingMatches(
      name: 'No overlaps',
      input: [
        _dummyLicenseMatchInstance(1.0, 'matchA', start: 50, end: 100),
        _dummyLicenseMatchInstance(0.95, 'matchB', start: 10, end: 40),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
      expected: [
        _dummyLicenseMatchInstance(1.0, 'matchA', start: 50, end: 100),
        _dummyLicenseMatchInstance(0.95, 'matchB', start: 10, end: 40),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
    );

    _testOverLappingMatches(
      name: 'discard a match that contains other with in less token density',
      input: [
        _dummyLicenseMatchInstance(1.0, 'matchA',
            start: 10, end: 70, tokensClaimed: 60),
        _dummyLicenseMatchInstance(0.7, 'matchB',
            start: 0, end: 100, tokensClaimed: 80),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
      expected: [
        _dummyLicenseMatchInstance(1.0, 'matchA',
            start: 10, end: 70, tokensClaimed: 60),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
    );

    _testOverLappingMatches(
      name: 'Does not discard match contained in other with less token density',
      input: [
        _dummyLicenseMatchInstance(1, 'matchB',
            start: 5, end: 95, tokensClaimed: 75),
        _dummyLicenseMatchInstance(0.9, 'matchA',
            start: 0, end: 100, tokensClaimed: 90),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
      expected: [
        _dummyLicenseMatchInstance(1, 'matchB',
            start: 5, end: 95, tokensClaimed: 75),
        _dummyLicenseMatchInstance(0.9, 'matchA',
            start: 0, end: 100, tokensClaimed: 90),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
    );

    _testOverLappingMatches(name: 'Removes a overlapping match', input: [
      _dummyLicenseMatchInstance(
        1,
        'matchA',
        start: 0,
        end: 100,
        tokensClaimed: 75,
      ),
      _dummyLicenseMatchInstance(
        0.9,
        'matchB',
        start: 200,
        end: 300,
        tokensClaimed: 90,
      ),
      _dummyLicenseMatchInstance(
        0.8,
        'matchC',
        start: 90,
        end: 180,
      ),
    ], expected: [
      _dummyLicenseMatchInstance(
        1,
        'matchA',
        start: 0,
        end: 100,
        tokensClaimed: 75,
      ),
      _dummyLicenseMatchInstance(
        0.9,
        'matchB',
        start: 200,
        end: 300,
        tokensClaimed: 90,
      ),
    ]);
  });

  group(('longestUnclaimedPercentage tests:'), () {
    _testUnclaimedPercentage(
      'Expect 1.0 for no matches found',
      [],
      1,
      100,
    );

    _testUnclaimedPercentage(
      'Expect 0.5',
      [_dummyLicenseMatchInstance(0.95, '', tokensClaimed: 50)],
      0.5,
      100,
    );

    _testUnclaimedPercentage(
      'Expect 1,0',
      [
        _dummyLicenseMatchInstance(0.95, '', tokensClaimed: 50),
        _dummyLicenseMatchInstance(0.9, '', tokensClaimed: 50),
      ],
      0,
      100,
    );
  });

  group('findLongestUnlaimedTokenRange', () {
    _testLongestUncliamedTokenRange(
      'Expect the unknown license length for no match found',
      [],
      100,
      100,
    );

    _testLongestUncliamedTokenRange(
      'Longest unclaimed tokens at start of license',
      [
        _dummyLicenseMatchInstance(0.9, '', start: 30, end: 60),
        _dummyLicenseMatchInstance(0.9, '', start: 70, end: 100),
      ],
      30,
      100,
    );

    _testLongestUncliamedTokenRange(
      'Longest unclaimed tokens at end of license',
      [
        _dummyLicenseMatchInstance(0.9, '', start: 0, end: 80),
      ],
      20,
      100,
    );

    _testLongestUncliamedTokenRange(
        'Longest unclaimed range in between',
        [
          _dummyLicenseMatchInstance(0.9, '', start: 30, end: 250),
          _dummyLicenseMatchInstance(0.89, '', start: 300, end: 550),
          _dummyLicenseMatchInstance(0.87, '', start: 710, end: 940),
        ],
        160,
        1000);
  });
}

void _testUnclaimedPercentage(
  String name,
  List<LicenseMatch> result,
  double expected,
  int unknownTokensCount,
) {
  test(name, () {
    final actual =
        claculateUnclaimedTokenPercentage(result, unknownTokensCount);

    expect(actual, expected);
  });
}

void _testLongestUncliamedTokenRange(
  String name,
  List<LicenseMatch> matches,
  int expected,
  int unknownTokens,
) {
  test(name, () {
    final actual = findLongestUnclaimedTokenRange(matches, unknownTokens);
    expect(actual, expected);
  });
}

void _testOverLappingMatches({
  required String name,
  required List<LicenseMatch> input,
  required List<LicenseMatch> expected,
}) {
  test(name, () {
    final actual = removeOverLappingMatches(input);

    _testOutput(actual, expected);
  });
}

void _testOutput(List<LicenseMatch> actual, List<LicenseMatch> expected) {
  expect(actual.length, expected.length);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].identifier, expected[i].identifier);
  }
}

LicenseMatch _dummyLicenseMatchInstance(
  double confidence,
  String identifier, {
  Range? diffRange,
  int tokensClaimed = 5,
  int start = 0,
  int end = 3,
}) {
  return LicenseMatch.createInstance(
      [],
      confidence,
      tokensClaimed,
      diffRange ?? dummyDiffRange,
      [],
      LicenseWithNGrams.parse(
          License.parse(identifier: identifier, content: 'take some text'), 3),
      Range(start, end));
}

final dummyDiffRange = Range(2, 20);
