import 'package:pana/src/license_detection/tokenizer.dart';
import 'package:test/test.dart';

void main() {
  // TODO: Add more test scenarios
  group('Tokenizer tests', () {
    test('Basic words', () {
      final text = 'basic text tokens';
      final expected = <Token>[
        Token('basic', 0, 0),
        Token('text', 1, 0),
        Token('tokens', 2, 0)
      ];

      final actual = tokenize(text);

      testOutput(actual, expected);
    });

    test('Ignore comments', () {
      final text = '// a comment line';
      final expected = <Token>[
        Token('a', 0, 0),
        Token('comment', 1, 0),
        Token('line', 2, 0),
      ];
      final actual = tokenize(text);

      testOutput(actual, expected);
    });

    test('Remove list items', () {
      final text = '1 some text\n1. a list item 1.1';
      final expected = <Token>[
        Token('1', 0, 0),
        Token('some', 1, 0),
        Token('text', 2, 0),
        Token('a', 3, 1),
        Token('list', 4, 1),
        Token('item', 5, 1),
        Token('1.1', 6, 1)
      ];

      final actual = tokenize(text);

      testOutput(actual, expected);
    });

    test('Ignore only punctuations and leading punctuations', () {
      final text = '&a \$ disappeared @#';
      final expected = <Token>[
        Token('a', 0, 0),
        Token('disappeared', 1, 0),
      ];

      final actual = tokenize(text);

      testOutput(actual, expected);
    });
  });
}

void testOutput(List<Token> actual, List<Token> expected) {
  expect(actual.length, expected.length);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].token, expected[i].token);
    expect(actual[i].line, expected[i].line);
    expect(actual[i].position, expected[i].position);
  }
}
