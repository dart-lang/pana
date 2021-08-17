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
    _testOveLappingMatches(
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

    _testOveLappingMatches(
      name: 'discard a match that contains other with in less token density',
      input: [
        _dummyLicenseMatchInstance(1.0, 'matchA', start: 10, end: 70, tokensClaimed: 60),
        _dummyLicenseMatchInstance(0.7, 'matchB', start: 0, end: 100, tokensClaimed: 80),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
      expected: [
        _dummyLicenseMatchInstance(1.0, 'matchA', start: 10, end: 70, tokensClaimed: 60),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
    );

    _testOveLappingMatches(
      name: 'Does not discard match contained in other with less token density',
      input: [
        _dummyLicenseMatchInstance(1, 'matchB', start: 5, end: 95, tokensClaimed: 75),
        _dummyLicenseMatchInstance(0.9, 'matchA', start: 0, end: 100, tokensClaimed: 90),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
      expected: [
   _dummyLicenseMatchInstance(1, 'matchB', start: 5, end: 95, tokensClaimed: 75),
        _dummyLicenseMatchInstance(0.9, 'matchA', start: 0, end: 100, tokensClaimed: 90),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ],
    );
  });
}

void _testOveLappingMatches({
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
  Range dummyDiffRange = dummyDiffRange,
  int tokensClaimed = 5,
  int start = 0,
  int end = 0,
}) {
  return LicenseMatch.dummyInstance(
      [],
      tokensClaimed,
      confidence,
      dummyDiffRange,
      [],
      LicenseWithNGrams.parse(
          License.parse(identifier: identifier, content: 'take some text'), 3),
      start,
      end);
}

const dummyDiffRange = Range(2, 20);

void madin(){
var m = removeOverLappingMatches([
        _dummyLicenseMatchInstance(1.0, 'matchA', start: 10, end: 70, tokensClaimed: 60),
        _dummyLicenseMatchInstance(0.7, 'matchB', start: 0, end: 100, tokensClaimed: 80),
        _dummyLicenseMatchInstance(0.65, 'matchC', start: 140, end: 200),
      ]);

      m.forEach((element) { 
        print(element.identifier);
      });
}