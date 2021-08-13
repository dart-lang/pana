import 'package:pana/src/license_detection/license_detector.dart';
import 'package:pana/src/third_party/diff_match_patch/diff.dart';
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

  test('removeDuplicate matches', () {
    final text = 'here is some text';
    final dummyDiffs = <Diff>[];
    final dummyDiffRange = Range(2, 20);
    final matches = [
      getDummyLicenseMatchInstance(
          text, 0.95, dummyDiffs, dummyDiffRange, 'matchA'),
      getDummyLicenseMatchInstance(
          text, 0.9, dummyDiffs, dummyDiffRange, 'matchB'),
      getDummyLicenseMatchInstance(
          text, 0.8, dummyDiffs, dummyDiffRange, 'matchA'),
    ];

    final expected = [
      getDummyLicenseMatchInstance(
          text, 0.95, dummyDiffs, dummyDiffRange, 'matchA'),
      getDummyLicenseMatchInstance(
          text, 0.9, dummyDiffs, dummyDiffRange, 'matchB'),
    ];

    final actual = removeDuplicates(matches);

    expect(actual.length, expected.length);

    for (var i = 0; i < actual.length; i++) {
      expect(actual[i].identifier, expected[i].identifier);
    }
  });
}

LicenseMatch getDummyLicenseMatchInstance(
  String text,
  double confidence,
  List<Diff> dummyDiffs,
  Range dummyDiffRange,
  String identifier,
) {
  return LicenseMatch(
    tokenize(text),
    0.9,
    LicenseWithNGrams.parse(
        License.parse(identifier: identifier, content: text), 3),
    dummyDiffs,
    dummyDiffRange,
  );
}
