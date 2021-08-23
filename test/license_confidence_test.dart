// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license_detector.dart';
import 'package:pana/src/third_party/diff_match_patch/diff.dart';
import 'package:test/test.dart';

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
      Diff(Operation.insert, 'extra text not belonging to known text')
    ];
    expected = Range(1, 2);

    _testDiffRange('Known matches exactly with a diff', diffs, known, expected);

    known = 'insert this text equal part of text ';
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
  String name,
  List<Diff> diffs,
  String known,
  Range expected,
) {
  test(name, () {
    final actual = diffRange(known, diffs);

    expect(actual.start, expected.start);
    expect(actual.end, expected.end);
  });
}

void testCofidencePercentage() {
  group('Test confidencePercentage:', () {
    test('avoid divide by zero', () {
      expect(confidencePercentage(0, 5), 1);
    });

    test('90% match', () {
      expect(confidencePercentage(100, 10), 0.9);
    });
  });
}

void testVerifyNoVersionChange() {
  group('test verifyNoVersionChange:', () {
    _testVerifyNoVersionChange(
      name: 'Version change',
      diffs: [
        Diff(Operation.equal, 'version'),
        Diff(Operation.insert, '1.1'),
      ],
    );

    var diffs = [
      Diff(Operation.equal, 'version'),
      Diff(Operation.delete, '1'),
      Diff(Operation.insert, '2'),
      Diff(Operation.equal, '.0'),
    ];

    _testVerifyNoVersionChange(
      name: 'Version change',
      diffs: diffs,
    );

    _testVerifyNoVersionChange(
      name: 'Not a version change',
      expectException: false,
      diffs: [
        Diff(Operation.equal, 'the standard version'),
        Diff(Operation.insert, '1.2')
      ],
    );

    _testVerifyNoVersionChange(
      name: 'Not a version number',
      expectException: false,
      diffs: [
        Diff(Operation.equal, 'version'),
        Diff(Operation.insert, '1.0-2')
      ],
    );
  });
}

void _testVerifyNoVersionChange(
    {required String name,
    required Iterable<Diff> diffs,
    bool expectException = true}) {
  test(name, () {
    if (expectException) {
      expect(() => verifyNoVersionChange(diffs, ''),
          throwsA(isA<LicenseMismatchException>()));
    } else {
      expect(() => verifyNoVersionChange(diffs, ''), returnsNormally);
    }
  });
}

void testVerifyNoGplChange() {
  group('test verifyNoGplChange:', () {
    _testVerifyNoGplChange(
      name: 'License name change by insertion',
      diffs: [Diff(Operation.equal, 'gnu'), Diff(Operation.insert, 'lesser')],
    );

    _testVerifyNoGplChange(
      name: 'Ignore "library" substitution by "lesser" in gnu context',
      diffs: [
        Diff(Operation.delete, 'library'),
        Diff(Operation.insert, 'lesser'),
        Diff(Operation.equal, 'gnu')
      ],
      expectException: false,
    );
  });
}

void _testVerifyNoGplChange(
    {required String name,
    required Iterable<Diff> diffs,
    bool expectException = true}) {
  test(name, () {
    if (expectException) {
      expect(() => verifyNoGplChange(diffs, ''),
          throwsA(isA<LicenseMismatchException>()));
    } else {
      expect(() => verifyNoGplChange(diffs, ''), returnsNormally);
    }
  });
}

void testInducedPhraseChange() {
  group('Induced phrase change:', () {
    test('Throws exception', () {
      expect(
          () => verifyInducedPhraseChange('Apache', [
                Diff(Operation.equal, 'some equal text'),
                Diff(Operation.insert, 'apache')
              ]),
          throwsA(isA<LicenseMismatchException>()));
    });

    test('Returns normally', () {
      expect(
          () => verifyInducedPhraseChange('Apache', [
                Diff(Operation.equal, 'some equal text'),
                Diff(Operation.insert, 'some inserted text')
              ]),
          returnsNormally);
    });
  });
}

void main() {
  testDiffRange();
  testCofidencePercentage();
  testVerifyNoVersionChange();
  testVerifyNoGplChange();
  testInducedPhraseChange();
}
