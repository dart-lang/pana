import 'package:pana/src/third_party/diff_match_patch/diff.dart';
import 'package:test/expect.dart';
import 'package:test/test.dart';

void testDiffMain() {
  var expected = <Diff>[];
  _testDiffMain(
    'Trivial Diff',
    expected,
    '',
    '',
  );

  expected = [
    Diff(Operation.equal, 'ab'),
    Diff(Operation.insert, '123'),
    Diff(Operation.equal, 'c')
  ];

  _testDiffMain(
    'diff_main: Simple insertion',
    expected,
    'abc',
    'ab123c',
  );

  expected = [
    Diff(Operation.equal, 'a'),
    Diff(Operation.delete, '123'),
    Diff(Operation.equal, 'bc')
  ];

  _testDiffMain(
    'diff_main: simple deletion',
    expected,
    'a123bc',
    'abc',
  );

  expected = [
    Diff(Operation.equal, 'a'),
    Diff(Operation.insert, '123'),
    Diff(Operation.equal, 'b'),
    Diff(Operation.insert, '456'),
    Diff(Operation.equal, 'c')
  ];

  _testDiffMain(
    'diff_main: two insertions',
    expected,
    'abc',
    'a123b456c',
  );

  expected = [
    Diff(Operation.equal, 'a'),
    Diff(Operation.delete, '123'),
    Diff(Operation.equal, 'b'),
    Diff(Operation.delete, '456'),
    Diff(Operation.equal, 'c')
  ];

  _testDiffMain(
    'diff_main: Two deletions.',
    expected,
    'a123b456c',
    'abc',
  );

  // Perform a real diff.
  // Switch off the timeout.
  diffTimeout = 0.0;
  expected = [
    Diff(Operation.delete, 'a'),
    Diff(Operation.insert, 'b'),
  ];

  _testDiffMain(
    'diff_main: Simple case #1.',
    expected,
    'a',
    'b',
  );

  expected = [
    Diff(Operation.delete, 'Apple'),
    Diff(Operation.insert, 'Banana'),
    Diff(Operation.equal, 's are a'),
    Diff(Operation.insert, 'lso'),
    Diff(Operation.equal, ' fruit.')
  ];

  _testDiffMain(
    'diff_main: Simple case #2.',
    expected,
    'Apples are a fruit.',
    'Bananas are also fruit.',
  );

  expected = [
    Diff(Operation.delete, 'a'),
    Diff(Operation.insert, '\u0680'),
    Diff(Operation.equal, 'x'),
    Diff(Operation.delete, '\t'),
    Diff(Operation.insert, '000'),
  ];

  _testDiffMain(
    'diff_main: Simple case #3.',
    expected,
    'ax\t',
    '\u0680x000',
  );

  expected = [
    Diff(Operation.delete, '1'),
    Diff(Operation.equal, 'a'),
    Diff(Operation.delete, 'y'),
    Diff(Operation.equal, 'b'),
    Diff(Operation.delete, '2'),
    Diff(Operation.insert, 'xab')
  ];

  _testDiffMain(
    'diff_main: Overlap #1.',
    expected,
    '1ayb2',
    'abxab',
  );

  expected = [
    Diff(Operation.insert, 'xaxcx'),
    Diff(Operation.equal, 'abc'),
    Diff(Operation.delete, 'y')
  ];

  _testDiffMain(
    'diff_main: Overlap #2.',
    expected,
    'abcy',
    'xaxcxabc',
  );

  expected = [
    Diff(Operation.delete, 'ABCD'),
    Diff(Operation.equal, 'a'),
    Diff(Operation.delete, '='),
    Diff(Operation.insert, '-'),
    Diff(Operation.equal, 'bcd'),
    Diff(Operation.delete, '='),
    Diff(Operation.insert, '-'),
    Diff(Operation.equal, 'efghijklmnopqrs'),
    Diff(Operation.delete, 'EFGHIJKLMNOefg')
  ];

  _testDiffMain(
    'diff_main: Overlap #3.',
    expected,
    'ABCDa=bcd=efghijklmnopqrsEFGHIJKLMNOefg',
    'a-bcd-efghijklmnopqrs',
  );

  expected = [
    Diff(Operation.insert, ' '),
    Diff(Operation.equal, 'a'),
    Diff(Operation.insert, 'nd'),
    Diff(Operation.equal, ' [[Pennsylvania]]'),
    Diff(Operation.delete, ' and [[')
  ];

  _testDiffMain(
    'diff_main: Large equality.',
    expected,
    'a [[Pennsylvania]] and [[',
    ' and [[Pennsylvania]]',
  );

  diffTimeout = 0.1; // 100ms
  var a =
      '`Twas brillig, and the slithy toves\nDid gyre and gimble in the wabe:\nAll mimsy were the borogoves,\nAnd the mome raths outgrabe.\n';
  var b =
      'I am the very model of a modern major general,\nI\'ve information vegetable, animal, and mineral,\nI know the kings of England, and I quote the fights historical,\nFrom Marathon to Waterloo, in order categorical.\n';
  // Increase the text lengths by 1024 times to ensure a timeout.
  for (var i = 0; i < 10; i++) {
    a += a;
    b += b;
  }
  var startTime = DateTime.now();
  diffMain(a, b);
  var endTime = DateTime.now();
  var elapsedSeconds = endTime.difference(startTime).inMilliseconds / 1000;

  // Test that we took at least the timeout period.
  test('diff_main: Timeout min', () {
    expect(diffTimeout, lessThanOrEqualTo(elapsedSeconds));
  });

  // Test that we didn't take forever (be forgiving).
  // Theoretically this test could fail very occasionally if the
  // OS task swaps or locks up for a second at the wrong moment.
  test('diff_main: Max Timeout', () {
    expect(diffTimeout * 2, greaterThan(elapsedSeconds));
  });

  diffTimeout = 0.0;
  // Test the linemode speedup.
  // Must be long to pass the 100 char cutoff.
  a = '1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n';
  b = 'abcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\n';

  _testDiffMain(
    'diff_main: Simple Line Mode',
    diffMain(a, b),
    a,
    b,
    checklines: true,
  );

  a = '123  4567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890';
  b = 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij';

  _testDiffMain(
    'diff_main: Single Line Mode',
    diffMain(a, b),
    a,
    b,
    checklines: true,
  );

  a = '1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n';
  b = 'abcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n';

  test('diff_main: Overlap mode', () {
    final textsLineMode = diffRebuildtexts(diffMain(
      a,
      b,
      checklines: true,
    ));
    final textsTextMode = diffRebuildtexts(diffMain(
      a,
      b,
    ));

    expect(textsLineMode.length, textsTextMode.length);
    expect(textsLineMode[0], textsTextMode[0]);
    expect(textsLineMode[1], textsTextMode[1]);
  });
}

void testDiffCommonPrefix() {
  group('diff_CommonPrefix tests: ', () {
    // Detect any common prefix.

    _testCommonPrefix(
      'Null case.',
      'abc',
      'xyz',
      0,
    );

    _testCommonPrefix(
      'Non-null case.',
      '1234abcdef',
      '1234xyz',
      4,
    );

    _testCommonPrefix(
      'Whole case.',
      '1234',
      '1234xyz',
      4,
    );
  });
}

void testDiffCommonSuffix() {
  // Detect any common suffix.

  group('diff_CommonSuffix tests:', () {
    // Detect any common prefix.
    _testCommonSuffix(
      'Null case.',
      'abc',
      'xyz',
      0,
    );

    _testCommonSuffix(
      'Non-null case.',
      'abcdef1234',
      'xyz1234',
      4,
    );

    _testCommonSuffix(
      'Whole case.',
      '1234',
      'xyz1234',
      4,
    );
  });
}

void testDiffCommonOverlap() {
  // Detect any common suffix.

  group('diff_commonOverlap:', () {
    // Detect any common prefix.
    _testCommonOverlap(
      'Null case.',
      '',
      'abcd',
      0,
    );

    _testCommonOverlap(
      'Whole case.',
      'abc',
      'abcd',
      3,
    );

    _testCommonOverlap(
      'No overlap.',
      '123456',
      'abcd',
      0,
    );

    _testCommonOverlap(
      'Overlap.',
      '123456xxx',
      'xxxabcd',
      3,
    );

    _testCommonOverlap(
      'Unicode.',
      'fi',
      '\ufb01i',
      0,
    );
  });
}

void testDiffHalfMatch() {
  group('diff_HalfMatch:', () {
    diffTimeout = 1.0;
    _testDiffHalfMatch(
      'No match #1.',
      '1234567890',
      'abcdef',
      null,
    );

    _testDiffHalfMatch(
      'No match #2.',
      '12345',
      '23',
      null,
    );

    _testDiffHalfMatch(
      'Single Match #1.',
      '1234567890',
      'a345678z',
      ['12', '90', 'a', 'z', '345678'],
    );

    _testDiffHalfMatch(
      'Single Match #2',
      'a345678z',
      '1234567890',
      ['a', 'z', '12', '90', '345678'],
    );

    _testDiffHalfMatch(
      'Single Match #3',
      'abc56789z',
      '1234567890',
      ['abc', 'z', '1234', '0', '56789'],
    );

    _testDiffHalfMatch(
      'Single Match #4',
      'a23456xyz',
      '1234567890',
      ['a', 'xyz', '1', '7890', '23456'],
    );

    _testDiffHalfMatch(
      'Multiple Matches #1.',
      '121231234123451234123121',
      'a1234123451234z',
      ['12123', '123121', 'a', 'z', '1234123451234'],
    );

    _testDiffHalfMatch(
      'Multiple Matches #2.',
      'x-=-=-=-=-=-=-=-=-=-=-=-=',
      'xx-=-=-=-=-=-=-=',
      ['', '-=-=-=-=-=', 'x', '', 'x-=-=-=-=-=-=-='],
    );

    _testDiffHalfMatch(
      'Multiple Matches #3.',
      'qHilloHelloHew',
      'xHelloHeHulloy',
      ['qHillo', 'w', 'x', 'Hulloy', 'HelloHe'],
    );

    // Optimal diff would be -q+x=H-i+e=lloHe+Hu=llo-Hew+y not -qHillo+x=HelloHe-w+Hulloy
    _testDiffHalfMatch(
      'Non-optimal halfmatch.',
      'qHilloHelloHew',
      'xHelloHeHulloy',
      ['qHillo', 'w', 'x', 'Hulloy', 'HelloHe'],
    );

    // Diff_Timeout = 0.0;
    // test('Optimal no halfmatch.',() => expect(diff_halfMatch('qHilloHelloHew', 'xHelloHeHulloy'), null,));
  });
}

void testDiffLineToChars() {
  group('diff_LineToChars:', () {
    // Convert lines down to characters.
    _testDiffLineToChars(
      'Shared lines',
      'alpha\nbeta\nalpha\n',
      'beta\nalpha\nbeta\n',
      {
        'chars1': '\u0001\u0002\u0001',
        'chars2': '\u0002\u0001\u0002',
        'lineArray': ['', 'alpha\n', 'beta\n']
      },
    );

    _testDiffLineToChars(
      'Empty string and blank lines.',
      '',
      'alpha\r\nbeta\r\n\r\n\r\n',
      {
        'chars1': '',
        'chars2': '\u0001\u0002\u0003\u0003',
        'lineArray': ['', 'alpha\r\n', 'beta\r\n', '\r\n']
      },
    );

    _testDiffLineToChars('No linebreaks.', 'a', 'b', {
      'chars1': '\u0001',
      'chars2': '\u0002',
      'lineArray': ['', 'a', 'b']
    });

    // More than 256 to reveal any 8-bit limitations.
    var n = 300;
    var lineList = <String>[];
    var charList = StringBuffer();

    for (var i = 1; i < n + 1; i++) {
      lineList.add('$i\n');
      charList.writeCharCode(i);
    }
    test(
        'Test initialization fail #1.',
        () => expect(
              lineList.length,
              isNot(n),
            ));

    var lines = lineList.join();
    var chars = charList.toString();
    test(
      'Test initialization fail #2',
      () => expect(n, chars.length),
    );
    lineList.insert(0, '');

    _testDiffLineToChars(
      'More than 256.',
      lines,
      '',
      {'chars1': chars, 'chars2': '', 'lineArray': lineList},
    );
  });
}

void testDiffCharsToLines() {
  group('diff_CharsToLines:', () {
    var diffs = [
      Diff(Operation.equal, '\u0001\u0002\u0001'),
      Diff(Operation.insert, '\u0002\u0001\u0002')
    ];

    _testDiffCharsToLines(
      'Shared lines.',
      diffs,
      ['', 'alpha\n', 'beta\n'],
      [
        Diff(Operation.equal, 'alpha\nbeta\nalpha\n'),
        Diff(Operation.insert, 'beta\nalpha\nbeta\n')
      ],
    );
    // More than 256 to reveal any 8-bit limitations.
    var n = 300;
    var lineList = <String>[];
    var charList = StringBuffer();

    for (var i = 1; i < n + 1; i++) {
      lineList.add('$i\n');
      charList.writeCharCode(i);
    }
    test(
        'Test initialization fail #3.',
        () => expect(
              lineList.length,
              isNot(n),
            ));

    var lines = lineList.join();
    var chars = charList.toString();
    test(
        'Test initialization fail #4',
        () => expect(
              n,
              isNot(chars.length),
            ));

    lineList.insert(0, '');

    diffs = [Diff(Operation.delete, chars)];

    _testDiffCharsToLines(
      'More than 256.',
      diffs,
      lineList,
      [Diff(Operation.delete, lines)],
    );

    // More than 65536 to verify any 16-bit limitation.
    lineList = [];
    for (var i = 0; i < 66000; i++) {
      lineList.add('$i\n');
    }

    chars = lineList.join();
    final results = diffLinesToChars(chars, '');
    diffs = [Diff(Operation.insert, results['chars1'] as String)];
    diffCharsToLines(diffs, results['lineArray'] as List<String>);
    test('More than 65536.', () => expect(chars, diffs[0].text));
  });
}

void testDiffCleanupMerge() {
  group('diff_Cleanup:', () {
    var actual = <Diff>[];
    _testDiffCleanupMerge('Null case.', actual, []);

    actual = [
      Diff(Operation.equal, 'a'),
      Diff(Operation.delete, 'b'),
      Diff(Operation.insert, 'c')
    ];

    _testDiffCleanupMerge('No change case.', actual, [
      Diff(Operation.equal, 'a'),
      Diff(Operation.delete, 'b'),
      Diff(Operation.insert, 'c')
    ]);

    actual = [
      Diff(Operation.equal, 'a'),
      Diff(Operation.equal, 'b'),
      Diff(Operation.equal, 'c')
    ];

    _testDiffCleanupMerge(
      'Merge equalities.',
      actual,
      [Diff(Operation.equal, 'abc')],
    );

    actual = [
      Diff(Operation.delete, 'a'),
      Diff(Operation.delete, 'b'),
      Diff(Operation.delete, 'c')
    ];

    _testDiffCleanupMerge(
      'Merge deletions.',
      actual,
      [Diff(Operation.delete, 'abc')],
    );

    actual = [
      Diff(Operation.insert, 'a'),
      Diff(Operation.insert, 'b'),
      Diff(Operation.insert, 'c')
    ];

    _testDiffCleanupMerge(
      'Merge insertions.',
      actual,
      [Diff(Operation.insert, 'abc')],
    );

    actual = [
      Diff(Operation.delete, 'a'),
      Diff(Operation.insert, 'b'),
      Diff(Operation.delete, 'c'),
      Diff(Operation.insert, 'd'),
      Diff(Operation.equal, 'e'),
      Diff(Operation.equal, 'f')
    ];

    _testDiffCleanupMerge(
      'Merge interweave.',
      actual,
      [
        Diff(Operation.delete, 'ac'),
        Diff(Operation.insert, 'bd'),
        Diff(Operation.equal, 'ef')
      ],
    );

    actual = [
      Diff(Operation.delete, 'a'),
      Diff(Operation.insert, 'abc'),
      Diff(Operation.delete, 'dc')
    ];

    _testDiffCleanupMerge(
      'Prefix and suffix detection.',
      actual,
      [
        Diff(Operation.equal, 'a'),
        Diff(Operation.delete, 'd'),
        Diff(Operation.insert, 'b'),
        Diff(Operation.equal, 'c')
      ],
    );

    actual = [
      Diff(Operation.equal, 'x'),
      Diff(Operation.delete, 'a'),
      Diff(Operation.insert, 'abc'),
      Diff(Operation.delete, 'dc'),
      Diff(Operation.equal, 'y')
    ];

    _testDiffCleanupMerge(
      'Prefix and suffix detection with equalities.',
      actual,
      [
        Diff(Operation.equal, 'xa'),
        Diff(Operation.delete, 'd'),
        Diff(Operation.insert, 'b'),
        Diff(Operation.equal, 'cy')
      ],
    );

    actual = [
      Diff(Operation.equal, 'a'),
      Diff(Operation.insert, 'ba'),
      Diff(Operation.equal, 'c')
    ];

    _testDiffCleanupMerge(
      'Slide edit left.',
      actual,
      [Diff(Operation.insert, 'ab'), Diff(Operation.equal, 'ac')],
    );

    actual = [
      Diff(Operation.equal, 'c'),
      Diff(Operation.insert, 'ab'),
      Diff(Operation.equal, 'a')
    ];

    _testDiffCleanupMerge(
      'Slide edit right.',
      actual,
      [Diff(Operation.equal, 'ca'), Diff(Operation.insert, 'ba')],
    );

    actual = [
      Diff(Operation.equal, 'a'),
      Diff(Operation.delete, 'b'),
      Diff(Operation.equal, 'c'),
      Diff(Operation.delete, 'ac'),
      Diff(Operation.equal, 'x')
    ];

    _testDiffCleanupMerge(
      'Slide edit left recursive.',
      actual,
      [Diff(Operation.delete, 'abc'), Diff(Operation.equal, 'acx')],
    );

    actual = [
      Diff(Operation.equal, 'x'),
      Diff(Operation.delete, 'ca'),
      Diff(Operation.equal, 'c'),
      Diff(Operation.delete, 'b'),
      Diff(Operation.equal, 'a')
    ];

    _testDiffCleanupMerge(
      'Slide edit right recursive.',
      actual,
      [Diff(Operation.equal, 'xca'), Diff(Operation.delete, 'cba')],
    );

    actual = [
      Diff(Operation.delete, 'b'),
      Diff(Operation.insert, 'ab'),
      Diff(Operation.equal, 'c')
    ];

    _testDiffCleanupMerge(
      'Empty merge.',
      actual,
      [Diff(Operation.insert, 'a'), Diff(Operation.equal, 'bc')],
    );

    actual = [
      Diff(Operation.equal, ''),
      Diff(Operation.insert, 'a'),
      Diff(Operation.equal, 'b')
    ];

    _testDiffCleanupMerge(
      'Empty equality.',
      actual,
      [Diff(Operation.insert, 'a'), Diff(Operation.equal, 'b')],
    );
  });
}

void testDiffCleanupSemanticLosses() {
  group('diff_Cleanup:', () {
    var actual = <Diff>[];
    _testDiffCleanupSemanticLosses('Null case.', actual, []);

    actual = [
      Diff(Operation.equal, 'AAA\r\n\r\nBBB'),
      Diff(Operation.insert, '\r\nDDD\r\n\r\nBBB'),
      Diff(Operation.equal, '\r\nEEE')
    ];

    _testDiffCleanupSemanticLosses('Blank lines.', actual, [
      Diff(Operation.equal, 'AAA\r\n\r\n'),
      Diff(Operation.insert, 'BBB\r\nDDD\r\n\r\n'),
      Diff(Operation.equal, 'BBB\r\nEEE')
    ]);

    actual = [
      Diff(Operation.equal, 'AAA\r\nBBB'),
      Diff(Operation.insert, ' DDD\r\nBBB'),
      Diff(Operation.equal, ' EEE')
    ];

    _testDiffCleanupSemanticLosses(
      'Line boundaries.',
      actual,
      [
        Diff(Operation.equal, 'AAA\r\n'),
        Diff(Operation.insert, 'BBB DDD\r\n'),
        Diff(Operation.equal, 'BBB EEE')
      ],
    );

    actual = [
      Diff(Operation.equal, 'The c'),
      Diff(Operation.insert, 'ow and the c'),
      Diff(Operation.equal, 'at.')
    ];

    _testDiffCleanupSemanticLosses(
      'Word boundaries.',
      actual,
      [
        Diff(Operation.equal, 'The '),
        Diff(Operation.insert, 'cow and the '),
        Diff(Operation.equal, 'cat.')
      ],
    );

    actual = [
      Diff(Operation.equal, 'The-c'),
      Diff(Operation.insert, 'ow-and-the-c'),
      Diff(Operation.equal, 'at.')
    ];

    _testDiffCleanupSemanticLosses(
      'Alphanumeric boundaries.',
      actual,
      [
        Diff(Operation.equal, 'The-'),
        Diff(Operation.insert, 'cow-and-the-'),
        Diff(Operation.equal, 'cat.')
      ],
    );

    actual = [
      Diff(Operation.equal, 'a'),
      Diff(Operation.delete, 'a'),
      Diff(Operation.equal, 'ax')
    ];

    _testDiffCleanupSemanticLosses(
      'Hitting the start.',
      actual,
      [Diff(Operation.delete, 'a'), Diff(Operation.equal, 'aax')],
    );

    actual = [
      Diff(Operation.equal, 'xa'),
      Diff(Operation.delete, 'a'),
      Diff(Operation.equal, 'a')
    ];

    _testDiffCleanupSemanticLosses(
      'Hitting the end.',
      actual,
      [Diff(Operation.equal, 'xaa'), Diff(Operation.delete, 'a')],
    );

    actual = [
      Diff(Operation.equal, 'The xxx. The '),
      Diff(Operation.insert, 'zzz. The '),
      Diff(Operation.equal, 'yyy.')
    ];

    _testDiffCleanupSemanticLosses(
      'Sentence boundaries.',
      actual,
      [
        Diff(Operation.equal, 'The xxx.'),
        Diff(Operation.insert, ' The zzz.'),
        Diff(Operation.equal, ' The yyy.')
      ],
    );
  });
}

void testDiffCleanupSemantic() {
  group('diff_CleanupSemantic', () {
    var actual = <Diff>[];
    _testDiffCleanupSemantic([], actual, 'Null case.');

    actual = [
      Diff(Operation.delete, 'ab'),
      Diff(Operation.insert, 'cd'),
      Diff(Operation.equal, '12'),
      Diff(Operation.delete, 'e')
    ];
    _testDiffCleanupSemantic([
      Diff(Operation.delete, 'ab'),
      Diff(Operation.insert, 'cd'),
      Diff(Operation.equal, '12'),
      Diff(Operation.delete, 'e')
    ], actual, 'No elimination #1.');

    actual = [
      Diff(Operation.delete, 'abc'),
      Diff(Operation.insert, 'ABC'),
      Diff(Operation.equal, '1234'),
      Diff(Operation.delete, 'wxyz')
    ];
    _testDiffCleanupSemantic([
      Diff(Operation.delete, 'abc'),
      Diff(Operation.insert, 'ABC'),
      Diff(Operation.equal, '1234'),
      Diff(Operation.delete, 'wxyz')
    ], actual, 'No elimination #2.');

    actual = [
      Diff(Operation.delete, 'a'),
      Diff(Operation.equal, 'b'),
      Diff(Operation.delete, 'c')
    ];
    _testDiffCleanupSemantic(
        [Diff(Operation.delete, 'abc'), Diff(Operation.insert, 'b')],
        actual,
        'Simple elimination.');

    actual = [
      Diff(Operation.delete, 'ab'),
      Diff(Operation.equal, 'cd'),
      Diff(Operation.delete, 'e'),
      Diff(Operation.equal, 'f'),
      Diff(Operation.insert, 'g')
    ];
    _testDiffCleanupSemantic(
        [Diff(Operation.delete, 'abcdef'), Diff(Operation.insert, 'cdfg')],
        actual,
        'Backpass elimination.');

    actual = [
      Diff(Operation.insert, '1'),
      Diff(Operation.equal, 'A'),
      Diff(Operation.delete, 'B'),
      Diff(Operation.insert, '2'),
      Diff(Operation.equal, '_'),
      Diff(Operation.insert, '1'),
      Diff(Operation.equal, 'A'),
      Diff(Operation.delete, 'B'),
      Diff(Operation.insert, '2')
    ];
    _testDiffCleanupSemantic(
        [Diff(Operation.delete, 'AB_AB'), Diff(Operation.insert, '1A2_1A2')],
        actual,
        'Multiple elimination.');

    actual = [
      Diff(Operation.equal, 'The c'),
      Diff(Operation.delete, 'ow and the c'),
      Diff(Operation.equal, 'at.')
    ];
    _testDiffCleanupSemantic([
      Diff(Operation.equal, 'The '),
      Diff(Operation.delete, 'cow and the '),
      Diff(Operation.equal, 'cat.')
    ], actual, 'Word boundaries.');

    actual = [Diff(Operation.delete, 'abcxx'), Diff(Operation.insert, 'xxdef')];
    _testDiffCleanupSemantic(
        [Diff(Operation.delete, 'abcxx'), Diff(Operation.insert, 'xxdef')],
        actual,
        'No overlap elimination.');

    actual = [
      Diff(Operation.delete, 'abcxxx'),
      Diff(Operation.insert, 'xxxdef')
    ];

    _testDiffCleanupSemantic([
      Diff(Operation.delete, 'abc'),
      Diff(Operation.equal, 'xxx'),
      Diff(Operation.insert, 'def')
    ], actual, 'Overlap elimination.');

    actual = [
      Diff(Operation.delete, 'xxxabc'),
      Diff(Operation.insert, 'defxxx')
    ];

    _testDiffCleanupSemantic([
      Diff(Operation.insert, 'def'),
      Diff(Operation.equal, 'xxx'),
      Diff(Operation.delete, 'abc')
    ], actual, 'Reverse overlap elimination.');

    actual = [
      Diff(Operation.delete, 'abcd1212'),
      Diff(Operation.insert, '1212efghi'),
      Diff(Operation.equal, '----'),
      Diff(Operation.delete, 'A3'),
      Diff(Operation.insert, '3BC')
    ];
    _testDiffCleanupSemantic([
      Diff(Operation.delete, 'abcd'),
      Diff(Operation.equal, '1212'),
      Diff(Operation.insert, 'efghi'),
      Diff(Operation.equal, '----'),
      Diff(Operation.delete, 'A'),
      Diff(Operation.equal, '3'),
      Diff(Operation.insert, 'BC')
    ], actual, 'Two overlap eliminations.');
  });
}

void testDiffBisect() {
  group('diff_Bisect:', () {
    // Normal.
    var a = 'cat';
    var b = 'map';
    // Since the resulting diff hasn't been normalized, it would be ok if
    // the insertion and deletion pairs are swapped.
    // If the order changes, tweak this test as required.
    var diffs = [
      Diff(Operation.delete, 'c'),
      Diff(Operation.insert, 'm'),
      Diff(Operation.equal, 'a'),
      Diff(Operation.delete, 't'),
      Diff(Operation.insert, 'p')
    ];
    // One year should be sufficient.
    var deadline = DateTime.now().add(const Duration(days: 365));
    _testDiffBisect(diffs, deadline, a, b, 'Normal.');

    // Timeout.
    diffs = [Diff(Operation.delete, 'cat'), Diff(Operation.insert, 'map')];
    // Set deadline to one year ago.
    deadline = DateTime.now().subtract(const Duration(days: 365));
    _testDiffBisect(diffs, deadline, a, b, 'Timeout.');
  });
}

void testWordDiffLevenshtein() {
  var diffs = [
    Diff(Operation.delete, 'delete three words'),
    Diff(Operation.insert, 'and insert four words'),
    Diff(Operation.equal, 'xyz')
  ];

  _testWordDiffLevenshtein(4, diffs, 'Levenshtein with trailing equality.');

  diffs = [
    Diff(Operation.equal, 'three equal words'),
    Diff(Operation.delete, 'delete three words'),
    Diff(Operation.insert, 'insert two')
  ];
  _testWordDiffLevenshtein(3, diffs, 'Levenshtein with leading equality.');

  diffs = [
    Diff(Operation.delete, 'delete exact 4 words'),
    Diff(Operation.equal, 'xyz'),
    Diff(Operation.insert, 'insert two')
  ];
  _testWordDiffLevenshtein(6, diffs, 'Levenshtein with middle equality.');
}

void _testDiffMain(
  String name,
  List<Diff> expected,
  String text1,
  String text2, {
  bool checklines = false,
}) =>
    test(name, () {
      _testOutput(diffMain(text1, text2, checklines: checklines), expected);
    });

void _testCommonPrefix(
  String name,
  String text1,
  String text2,
  int expected,
) {
  test(
      name,
      () => expect(
            diffCommonPrefix(text1, text2),
            expected,
          ));
}

void _testCommonSuffix(
  String name,
  String text1,
  String text2,
  int expected,
) {
  test(
      name,
      () => expect(
            diffCommonSuffix(text1, text2),
            expected,
          ));
}

void _testCommonOverlap(
  String name,
  String text1,
  String text2,
  int expected,
) {
  test(
      name,
      () => expect(
            diffCommonOverlap(text1, text2),
            expected,
          ));
}

void _testDiffHalfMatch(
  String name,
  String text1,
  String text2,
  List<String>? expected,
) {
  test(name, () {
    if (expected == null) {
      expect(diffHalfMatch(text1, text2), null);
    } else {
      final actual = diffHalfMatch(text1, text2);

      expect(actual!.length, expected.length);

      for (var i = 0; i < actual.length; i++) {
        expect(actual[i], expected[i]);
      }
    }
  });
}

void _testDiffLineToChars(
  String name,
  String text1,
  String text2,
  Map<String, dynamic> expected,
) {
  test(name, () {
    final actual = diffLinesToChars(text1, text2);
    expect(
      actual['chars1'],
      expected['chars1'],
    );
    expect(
      actual['chars2'],
      expected['chars2'],
    );
    expect(
      actual['lineArray'].length,
      expected['lineArray'].length,
    );

    for (var i = 0; i < (actual['lineArray'] as List<String>).length; i++) {
      expect(actual['lineArray'][i], expected['lineArray'][i]);
    }
  });
}

void _testDiffCharsToLines(
  String name,
  List<Diff> actual,
  List<String> input,
  List<Diff> expected,
) {
  test(name, () {
    diffCharsToLines(actual, input);

    _testOutput(actual, expected);
  });
}

void _testDiffCleanupMerge(
    String name, List<Diff> actual, List<Diff> expected) {
  test(name, () {
    diffCleanupMerge(actual);

    _testOutput(actual, expected);
  });
}

void _testDiffCleanupSemanticLosses(
    String name, List<Diff> actual, List<Diff> expected) {
  test(name, () {
    diffCleanupSemanticLossless(actual);

    _testOutput(actual, expected);
  });
}

void _testDiffCleanupSemantic(
  List<Diff> expected,
  List<Diff> actual,
  String name,
) {
  test(name, () {
    diffCleanupSemantic(actual);

    _testOutput(actual, expected);
  });
}

void _testDiffBisect(
  List<Diff> expected,
  DateTime deadline,
  String text1,
  String text2,
  String name,
) {
  test(name, () {
    _testOutput(diffBisect(text1, text2, deadline), expected);
  });
}

void _testWordDiffLevenshtein(int expected, List<Diff> input, String name) {
  test(name, () {
    expect(diffLevenshteinWord(input), expected);
  });
}

void testCleanupEfficiency() {
  _testCleanupEfficiency(
    name: 'diff_cleanupEfficiency: Null case.',
    expected: [],
    input: [],
  );

  _testCleanupEfficiency(
    name: 'diff_cleanupEfficiency: No elimination.',
    expected: [
      Diff(Operation.delete, 'ab'),
      Diff(Operation.insert, '12'),
      Diff(Operation.equal, 'wxyz'),
      Diff(Operation.delete, 'cd'),
      Diff(Operation.insert, '34')
    ],
    input: [
      Diff(Operation.delete, 'ab'),
      Diff(Operation.insert, '12'),
      Diff(Operation.equal, 'wxyz'),
      Diff(Operation.delete, 'cd'),
      Diff(Operation.insert, '34'),
    ],
  );

  _testCleanupEfficiency(
    name: 'diff_cleanupEfficiency: Four-edit elimination.',
    expected: [
      Diff(Operation.delete, 'abxyzcd'),
      Diff(Operation.insert, '12xyz34')
    ],
    input: [
      Diff(Operation.delete, 'ab'),
      Diff(Operation.insert, '12'),
      Diff(Operation.equal, 'xyz'),
      Diff(Operation.delete, 'cd'),
      Diff(Operation.insert, '34')
    ],
  );

  _testCleanupEfficiency(
    name: 'diff_cleanupEfficiency: Three-edit elimination.',
    expected: [Diff(Operation.delete, 'xcd'), Diff(Operation.insert, '12x34')],
    input: [
      Diff(Operation.insert, '12'),
      Diff(Operation.equal, 'x'),
      Diff(Operation.delete, 'cd'),
      Diff(Operation.insert, '34')
    ],
  );

  _testCleanupEfficiency(
      name: 'diff_cleanupEfficiency: Backpass elimination.',
      expected: [
        Diff(Operation.delete, 'abxyzcd'),
        Diff(Operation.insert, '12xy34z56')
      ],
      input: [
        Diff(Operation.delete, 'ab'),
        Diff(Operation.insert, '12'),
        Diff(Operation.equal, 'xy'),
        Diff(Operation.insert, '34'),
        Diff(Operation.equal, 'z'),
        Diff(Operation.delete, 'cd'),
        Diff(Operation.insert, '56')
      ]);

  _testCleanupEfficiency(
      name: 'diff_cleanupEfficiency: High cost elimination.',
      diffEditCost: 5,
      expected: [
        Diff(Operation.delete, 'abwxyzcd'),
        Diff(Operation.insert, '12wxyz34')
      ],
      input: [
        Diff(Operation.delete, 'ab'),
        Diff(Operation.insert, '12'),
        Diff(Operation.equal, 'wxyz'),
        Diff(Operation.delete, 'cd'),
        Diff(Operation.insert, '34')
      ]);
}

void _testCleanupEfficiency(
    {required String name,
    required List<Diff> expected,
    required List<Diff> input,
    int diffEditCost = 4}) {
  test(name, () {
    diffCleanupEfficiency(input, diffEditCost: diffEditCost);
    _testOutput(
      input,
      expected,
    );
  });
}

void _testOutput(List<Diff> actual, List<Diff> expected) {
  expect(actual.length, expected.length);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].text, expected[i].text);
    expect(actual[i].operation, expected[i].operation);
  }
}
