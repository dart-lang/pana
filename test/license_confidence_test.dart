import 'package:pana/src/license_detection/confidence.dart';
import 'package:pana/src/third_party/diff_match_patch/diff.dart';
import 'package:pana/src/license_detection/token_matcher.dart';
import 'package:test/test.dart';

void testScoreDiff() {
  group('scoreDiffs:', () {
    var diffs = [
      Diff(Operation.equal, 'version'),
      Diff(Operation.insert, '1.1')
    ];

    _testScoreDiff('Version change', diffs, versionChange);

    diffs = [
      Diff(Operation.equal, 'version'),
      Diff(Operation.delete, '1'),
      Diff(Operation.insert, '2'),
      Diff(Operation.equal, '.0'),
    ];

    DiffMatchPatch().diffCleanupSemantic(diffs);
    _testScoreDiff('Version change', diffs, versionChange);

    diffs = [
      Diff(Operation.equal, 'the standard version'),
      Diff(Operation.insert, '1.2')
    ];

    _testScoreDiff('Not a version change', diffs, 1);

    diffs = [Diff(Operation.equal, 'version'), Diff(Operation.insert, '1.0-2')];

    _testScoreDiff(
      'Not a version number',
      diffs,
      1,
    );

    diffs = [Diff(Operation.equal, 'gnu'), Diff(Operation.insert, 'lesser')];

    _testScoreDiff(
      'License name change by insertion',
      diffs,
      lesserGplChange,
    );

    diffs = [
      Diff(Operation.delete, 'library'),
      Diff(Operation.insert, 'lesser'),
      Diff(Operation.equal, 'gnu')
    ];

    _testScoreDiff(
      'Ignore "library" substitution by "lesser" in gnu context',
      diffs,
      1,
    );
  });
}

void _testScoreDiff(
  String name,
  List<Diff> diffs,
  int expected,
) {
  test(name, () {
    expect(scoreDiffs(diffs), expected);
  });
}

void testDiffRange() {
  group('diffRange test:', () {
    var known = 'exact match';
    var diffs = [Diff(Operation.equal, 'exact match')];
    var expected = Range(0, 1);

    _testDiffRange('No changes', diffs, known, expected);

    known = 'equal part of text';
    diffs = [
      Diff(Operation.delete, 'previous deleted text '),
      Diff(Operation.equal, 'equal part of text'),
      Diff(Operation.insert, 'extra deleted text')
    ];
    expected = Range(1, 2);

    _testDiffRange('Known matches exactly with a diff', diffs, known, expected);

    known = 'insert this text equal part of text';
    diffs = [
      Diff(Operation.insert, 'insert this text '),
      Diff(Operation.equal, 'equal part of text'),
      Diff(Operation.delete, ' this part was deleted')
    ];
    expected = Range(0, 3);

    _testDiffRange('No exact match', diffs, known, expected);
  });
}


void _testDiffRange(
    String name, List<Diff> diffs, String known, Range expected) {
  test(name, () {
    final actual = diffRange(known, diffs);

    expect(actual.start, expected.start);
    expect(actual.end, expected.end);
  });
}

void testCofidencePercentage(){
  group('Test confidencePercentage', (){
    test('avoid divide by zero',(){
      expect(confidencePercentage(0,5), 1);
    });

    test('90% match', (){
      expect(confidencePercentage(100, 10), 0.9);
    });
  });
}

void main() {
  testScoreDiff();
  testDiffRange();
  testCofidencePercentage();
}
