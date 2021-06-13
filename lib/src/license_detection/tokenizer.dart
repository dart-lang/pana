import 'dart:collection';
import 'dart:convert';

import 'package:meta/meta.dart';
// import 'package:source_span/source_span.dart';

@sealed
class Token {
  final String token;
  final int? position;
  final int line;

  // TODO : Handle offset and location using source span.
  // final SourceSpan sourceSpan;

  Token(this.token, this.position, this.line);
}

const lineSplitter = LineSplitter();

/// Create tokens and
/// normalizes them using the approach of [google licenseClassifier]
/// to provide better chances of matching.
/// [google licenseClassifier]  https://github.com/google/licenseclassifier/blob/bb04aff29e72e636ba260ec61150c6e15f111d7e/v2/tokenizer.go#L85
List<Token> tokenize(String text) {
  var tokens = <Token>[];
  var offset = 0;
  var lines = lineSplitter.convert(text);
  var position = 0;

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    var buffer = StringBuffer();
    var prevSignificant = false;

    for (var rune in line.runes) {
      offset++;
      if (!(_isDigit(rune) || _isAsciiLower(rune)) && !prevSignificant) {
        continue;
      }

      if (_isSpace(rune)) {
        if (buffer.isNotEmpty) {
          _addToken(offset, buffer.toString(), position, i, tokens, text);

          buffer.clear();
        }
        prevSignificant = false;
        continue;
      }

      buffer.write(String.fromCharCode(rune));
      prevSignificant = true;
    }
    if (buffer.isNotEmpty) {
      _addToken(offset, buffer.toString(), position, i, tokens, text);
    }

    _addToken(offset, '\n', position, i, tokens, text);
  }

  //Guideline 7.1.1: Ignore list item for matching purposes.
  tokens = _removeListItems(tokens);

  return tokens;
}

void _addToken(int offset, String token, int position, int line,
    List<Token> tokens, String normText) {
  tokens.add(Token(token, position++, line));
}

List<Token> _removeListItems(List<Token> tokens) {
  var newLine = true;
  var position = 0;
  var output = <Token>[];

  for (var i = 0; i < tokens.length; i++) {
    if (newLine && isListItem(tokens[i].token)) {
      continue;
    }

    if (tokens[i].token == '\n') {
      newLine = true;
      continue;
    }

    newLine = false;

    final text = _cleanToken(tokens[i].token);

    final tok = Token(text, position++, tokens[i].line);

    output.add(tok);
  }

  return output;
}

String _cleanToken(String tok) {
  final runes = tok.runes;
  var buffer = StringBuffer();

  if (!_isAsciiLower(runes.first)) {
    if (_isDigit(runes.first)) {
      runes.forEach((rune) {
        if (_isDigit(rune) || rune == _dot || rune == _hiphen) {
          buffer.write(String.fromCharCode(rune));
        }
      });

      var text = buffer.toString();

      if (text.runes.last == _dot) {
        text = text.substring(0, text.length);
      }

      return text;
    }
  }

  runes.forEach((rune) {
    if (_isAsciiLower(rune)) {
      buffer.write(String.fromCharCode(rune));
    }
  });
  return buffer.toString();
}

bool _isSpace(int rune) {
  return rune == 32;
}

bool _isDigit(int rune) {
  return (rune > 47 && rune < 58);
}

bool _isAsciiLower(int rune) {
  return (rune > 96 && rune < 123);
}

bool isListItem(String token) {
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

final _headers = HashSet.from(
    'q w e r t y u i o p a s d f g h j k l z x c v b n m i ii iii iv vi vii ix xi xii'
        .split(' '));

final _numberHeaderRe = RegExp(r'^\d{1,2}(\.\d{1,2})*[\.)]$');

const int _dot = 46;
const int _hiphen = 45;
