// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'license_detector.dart';

/// A token in this context is a sequence of characters
/// scanned from the original text separated by a space
/// or new line.
@visibleForTesting
@sealed
class Token {
  /// Normalized form of the text in [span].
  final String value;

  /// Zero based position of token in a list of [Token]s obtained by tokenizing license text.
  ///
  /// License when tokenized through [tokenize] method yields a list of [Token].
  /// The [index] denotes the offset (or index) of the token in this list.
  final int index;

  /// Location details of the token in original text.
  final SourceSpan span;

  @visibleForTesting
  Token(this.value, this.index, this.span);

  Token._fromSpan(this.span, this.index)
      : value = _normalizeWord(span.text.toLowerCase());
}

/// Tokenizes license text and returns a list of [Token]s.
///
/// The tokens are scanned and normalized according to this procedure.
/// 1. Tokens are words separated by spaces or new line. Ex - `hello new\nworld` -->[`hello`, `new`, `world`,].
/// 2. Any standalone punctuations texts are ignored. Ex - `// % ^&^&*^ hello` --> [`hello`,]
/// 3. Leading punctuations are ignored. Ex - `!hello $world&` --> [`hello`, `world&`,]
/// 4. Tokens resembling list items are ignored. Ex - `1.`, `ix.`, `a)` .
/// 5. Any tokens starting with alphabet are further cleaned to remove any
///    non-alphabet characters. Ex - `(hello wo$r1ld` --> [`hello`, `world`,]
/// 6. If a token starts with digit, any characters except `.`, `-` in the token value will be ignored.
///    Dot at the end of the token will also be ignored. `1!@#$.1.1 1-1hj.23.` --> [`1.1.1`, `1-1.23`,].
@visibleForTesting
List<Token> tokenize(String text) {
  final _scanner = SpanScanner(text);

  var tokens = <Token>[];
  var tokenID = 0;

  Token? nextToken() {
    while (!_scanner.isDone) {
      if (_scanner.scan(_wordRegex)) {
        return Token._fromSpan(_scanner.lastSpan!, tokenID++);
      }

      // Store new line tokens to identify and ignore tokens
      // resembling list items while cleaning tokens.
      if (_scanner.scan(_newLineRegex)) {
        return Token('\n', tokenID++, _scanner.lastSpan!);
      }

      // Ignore whitespace
      if (_scanner.scan(_horizontalWhiteSpaceRegex)) {
        continue;
      }

      // If none of the above conditions match, this implies
      // the scanner is at standalone punctuation mark or leading
      // punctuation in a word. Ignore them and move the scanner forward.
      _scanner.readChar();
    }
    return null;
  }

  /// Scans through the input text and creates a list of [Token].
  ///
  /// Whitespace, leading or pure punctuation texts are ignored as they are not significant.
  /// But newLine token is stored to deal with list Items.
  while (!_scanner.isDone) {
    final token = nextToken();

    if (token != null) {
      tokens.add(token);
    }
  }

  /// Removes unnecessary tokens and cleans token value.
  ///
  /// Some tokens such as newLine and list items are removed
  /// according to [SPDX Guidelines][1] and the values of
  /// remaining token values are cleaned using [google licenseClassifier][] approach.
  ///
  /// [1]: https://github.com/spdx/spdx-spec/blob/v2.2/chapters/appendix-II-license-matching-guidelines-and-templates.md
  /// [google licenseClassifier]: https://github.com/google/licenseclassifier/blob/bb04aff29e72e636ba260ec61150c6e15f111d7e/v2/tokenizer.go#L34
  tokens = _cleanTokens(tokens);

  return tokens;
}

List<Token> _cleanTokens(List<Token> tokens) {
  var output = <Token>[];
  var tokenID = 0;
  var firstInLine = true;
  final len = tokens.length;
  for (var i = 0; i < len; i++) {
    var token = tokens[i];
    // Ignore new line tokens for now.
    // If accuracy of detection is low apply
    // Guideline 2.1.4: Text that can be omitted from license.
    if (_newLineRegex.hasMatch(token.value)) {
      firstInLine = true;
      continue;
    }

    // Ignores list items.
    if (firstInLine && _isListItem(token.value)) {
      continue;
    }

    firstInLine = false;

    var text = _cleanToken(token.value);

    final textMap = _remainingEquivalentWords[text];

    if (textMap != null) {
      if (i + 1 < len) {
        final nextToken = tokens[i + 1];
        if (textMap[0] == _cleanToken(nextToken.value)) {
          if (text == 'copyright') {
            output.add(Token(text, tokenID++, token.span));
            token = tokens[i + 1];
          }
          text = textMap[1];
          i++;
        }
      }
    }

    output.add(Token(text, tokenID++, token.span));
  }

  return output;
}

/// Normalizes the tokens using the approach of [google licenseClassifier]
/// to provide better chances of matching.
///
/// [google licenseClassifier]  https://github.com/google/licenseclassifier/blob/bb04aff29e72e636ba260ec61150c6e15f111d7e/v2/tokenizer.go#L85
String _cleanToken(String tok) {
  if (tok.startsWith(RegExp(r'[^a-z]'))) {
    if (tok.startsWith(RegExp(r'\d'))) {
      var text = tok.replaceAll(RegExp(r'[^\d\.-]'), '');

      if (text.endsWith('.')) {
        text = text.substring(0, text.length - 1);
      }

      return text;
    }
  }

  var text = tok.replaceAll(RegExp(r'[^a-z]'), '');

  // If this is a varietal word normalize it according to
  // Guideline 8.1.1: Legally equal words must be treated same.
  text = _equivalentWords[text] ?? text;
  return text;
}

bool _isListItem(String token) {
  final end = token[token.length - 1];
  final start = token.substring(0, token.length - 1);

  if ((end == '.' || end == ')') && _headers.contains(start)) {
    return true;
  }

  if (_numberHeaderRe.hasMatch(token)) {
    return true;
  }

  return false;
}

String _normalizeWord(String text) {
  // Guideline 5: Equivalent Punctuation marks.
  _equivalentPunctuationMarks.forEach((reg, value) {
    text = text.replaceAll(reg, value);
  });

  return text;
}

final _headers = HashSet.from(
    'q w e r t y u i o p a s d f g h j k l z x c v b n m i ii iii iv vi vii ix xi xii xiii xiv xv'
        .split(' '));

final _numberHeaderRe = RegExp(r'^\d{1,2}(\.\d{1,2})*[\.)]$');

final _horizontalWhiteSpaceRegex = RegExp(r'[^\S\r\n]+');

final Map<RegExp, String> _equivalentPunctuationMarks = {
  // Guideline 5.1.2: All variants of dashes considered equivalent.
  RegExp(r'[-֊־᠆‐‑–—﹘﹣－‒⁃⁻⎯─⏤]'): '-',

  // Guideline Guideline 5.1.3: All variants of quotations considered equivalent.
  RegExp(r'[“‟”’"‘‛❛❜〝〞«»‹›❝❞]'): "'",

  // Guideline 9.1.1: “©”, “(c)”, or “Copyright” should be considered equivalent and interchangeable.
  RegExp(r'©'): '(c)'
};

final _wordRegex = RegExp(r'[\w\d][^\s]*');
final _newLineRegex = RegExp(r'(?:\n|\r\n|\r|\u0085)');

/// Words considered legally equivalent according [SPDX corpus][1].
///
/// [1]: https://github.com/spdx/license-list-XML/blob/master/equivalentwords.txt
final _equivalentWords = {
  'acknowledgment': 'acknowledgement',
  'analogue': 'analog',
  'analyse': 'analyze',
  'artefact': 'artifact',
  'authorization': 'authorisation',
  'authorized': 'authorised',
  'calibre': 'caliber',
  'canceled': 'cancelled',
  'capitalizations': 'capitalisations',
  'catalogue': 'catalog',
  'categorise': 'categorize',
  'centre': 'center',
  'copyrightholder': 'copyrightowner',
  'emphasised': 'emphasized',
  'favor': 'favour',
  'favorite': 'favourite',
  'fulfil': 'fulfill',
  'fulfillment': 'fulfilment',
  'initialise': 'initialize',
  'judgment': 'judgement',
  'labelling': 'labeling',
  'labor': 'labour',
  'licence': 'license',
  'maximize': 'maximise',
  'modelled': 'modeled',
  'modelling': 'modeling',
  'offence': 'offense',
  'optimise': 'optimize',
  'organization': 'organisation',
  'organize': 'organise',
  'practice': 'practise',
  'programme': 'program',
  'realise': 'realize',
  'recognise': 'recognize',
  'signalling': 'signaling',
  'sublicence': 'sublicense',
  'utilisation': 'utilization',
  'whilst': 'while',
  'wilful': 'wilfull',
  'http:': 'https:',
};

final _remainingEquivalentWords = {
  'copyright': ['holder', 'owner'],
  'per': ['cent', 'percent'],
  'sub': ['license', 'sublicense']
};
