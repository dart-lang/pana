import 'package:petitparser/petitparser.dart';

/// Grammar for Gradle
class GradleGrammerDefinition extends GrammarDefinition {
  @override
  Parser start() => ref0(value).end();

  /// A token, smallest unit to parse
  Parser token(Object source, [String name]) {
    if (source is String) {
      return source.toParser(message: 'Expected ${name ?? source}').trim();
    } else if (source is Parser) {
      ArgumentError.checkNotNull(name, 'name');
      return source.flatten('Expected $name').trim();
    } else {
      throw ArgumentError('Unknown token type: $source.');
    }
  }

  /// Prodctions to parse a block of elements
  Parser block() => ref1(token, '{') & ref0(elements) & ref1(token, '}');

  /// A list of key-value pairs seperated by a new line
  Parser elements() =>
      ref0(pair).separatedBy(ref1(token, '\n'), includeSeparators: false);

  /// Proudctions to parse each block
  Parser members() =>
      ref0(pair).separatedBy(ref1(token, '\n'), includeSeparators: false);

  /// a key-value pair seperated by a whitespace
  Parser pair() => ref0(stringToken) & ref1(token, ' ') & ref0(value);

  /// Primitive value tokens
  Parser trueToken() => ref1(token, 'true');
  Parser falseToken() => ref1(token, 'false');
  Parser stringToken() => ref2(token, ref0(stringPrimitive), 'string');
  Parser numberToken() => ref2(token, ref0(numberPrimitive), 'number');

  /// Possible values for parsing
  Parser value() => [
        ref0(members),
        ref0(block),
        ref0(stringToken),
        ref0(numberToken),
        ref0(trueToken),
        ref0(falseToken),
      ].toChoiceParser(failureJoiner: selectFarthestJoined);

  Parser characterPrimitive() => pattern('^"\\');
  Parser stringPrimitive() =>
      char('"') & ref0(characterPrimitive).star() & char('"');
  Parser numberPrimitive() => (digit().plus());
}

/// Parser for Gradle
class GradleParserDefinition extends GradleGrammerDefinition {
  @override
  Parser block() => super.block().map((block) => block[1] ?? {});

  @override
  Parser members() => super.members().map((members) {
        final result = {};
        if (members[1] != null) {
          for (final element in members[1]) {
            result[element[0]] = element[2];
          }
        }
        return result;
      });

  @override
  Parser trueToken() => super.trueToken().map((boolean) => true);
  @override
  Parser falseToken() => super.falseToken().map((boolean) => false);
  @override
  Parser stringToken() => ref0(stringPrimitive).trim();
  @override
  Parser numberToken() =>
      super.numberToken().map((number) => num.parse(number.toString()));

  @override
  Parser stringPrimitive() =>
      super.stringPrimitive().map((each) => each[1].join());
}

/// Test fucntion
void parseGradle() {
  final gradle = GradleParserDefinition();
  final result = gradle.build();
  final parsed = result.parse('''
  android {
    minSdk
  }
  ''');

  print(parsed);
}

void main() {
  parseGradle();
}
