// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license_detector.dart';
import 'package:source_span/source_span.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

void main() {
  group('Basic Tokenizer tests', () {
    testTokenizer('Ignore standalone punctuations',
        text: '// hello! ^& world %^& 1.1',
        expected: [
          'hello',
          'world',
          '1.1',
        ]);

    testTokenizer('Normalize equivalent words',
        text: 'analogue  favorite per cent copyright holder copyright-holder ',
        expected: [
          'analog',
          'favourite',
          'percent',
          'copyright',
          'owner',
          'copyrightowner'
        ]);

    testTokenizer('Ignore punctuations at start of word',
        text: '// !hello @#world -1.1.1',
        expected: [
          'hello',
          'world',
          '1.1.1',
        ]);

    testTokenizer('Ignore punctuations in between a textual world',
        text: '// hell@o wo\$%^rld', expected: ['hello', 'world']);

    testTokenizer('Allow only hyphens and dots if token starts with digit',
        text: 'H.E.L.L.O W.O.R.L.D 1!.2#-3',
        expected: [
          'hello',
          'world',
          '1.2-3',
        ]);

    testTokenizer('Ignore List Items',
        text: '// 1) hello world.\n   vii. This is a text vii.',
        expected: [
          'hello',
          'world',
          'this',
          'is',
          'a',
          'text',
          'vii',
        ]);

    // Tokenize at space or new line.
    testTokenizer('Basic tokenization',
        text: 'hello    world\r\n take some\n tokens',
        expected: [
          'hello',
          'world',
          'take',
          'some',
          'tokens',
        ]);
  });

  test('Complex tokenizer test', () {
    final text = '''Copyright (C) 

Permission to use/copy, modify    granted.''';

    final expected = <Token>[
      Token(
        'copyright',
        0,
        SourceSpan(
          SourceLocation(0, line: 0),
          SourceLocation(9, line: 0),
          'Copyright',
        ),
      ),
      Token(
        'c',
        1,
        SourceSpan(
          SourceLocation(11, line: 0),
          SourceLocation(13, line: 0),
          'C)',
        ),
      ),
      Token(
        'permission',
        2,
        SourceSpan(
          SourceLocation(16, line: 2),
          SourceLocation(26, line: 2),
          'Permission',
        ),
      ),
      Token(
        'to',
        3,
        SourceSpan(
          SourceLocation(27, line: 2),
          SourceLocation(29, line: 2),
          'to',
        ),
      ),
      Token(
        'usecopy',
        4,
        SourceSpan(
          SourceLocation(30, line: 2),
          SourceLocation(39, line: 2),
          'use/copy,',
        ),
      ),
      Token(
        'modify',
        5,
        SourceSpan(
          SourceLocation(40, line: 2),
          SourceLocation(46, line: 2),
          'modify',
        ),
      ),
      Token(
        'granted',
        6,
        SourceSpan(
          SourceLocation(50, line: 2),
          SourceLocation(58, line: 2),
          'granted.',
        ),
      ),
    ];

    final actual = tokenize(text);

    // expect(actual.length, expected.length);

    for (var i = 0; i < actual.length; i++) {
      expect(actual[i].value, expected[i].value);
      expect(actual[i].span.start.line, expected[i].span.start.line);
      expect(actual[i].span.text, expected[i].span.text);
      expect(actual[i].span.start.offset, expected[i].span.start.offset);
      expect(actual[i].span.end.offset, expected[i].span.end.offset);
    }
  });
}

void testTokenizer(String name,
    {required String text, required List<String> expected}) {
  test(name, () => testOutput(tokenize(text), expected));
}

void testOutput(List<Token> actual, List<String> expected) {
  expect(actual.length, expected.length);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].value, expected[i]);
    expect(actual[i].index, i);
  }
}
