// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:math';

import 'license_detector.dart' show Token;

/// A pair representing matching tokens from unknown to known sequences.
typedef TokenPair = ({Token unknown, Token known});

/// Describes an edit operation on the token list.
abstract class TokenOp {}

/// Describes an insertion into the unknown tokens.
class InsertOp extends TokenOp {
  final List<Token> tokens;
  InsertOp(this.tokens);
}

/// Describes a deletion from the known tokens.
class DeleteOp extends TokenOp {
  final List<Token> tokens;
  DeleteOp(this.tokens);
}

/// Describes a match of token pairs.
class MatchOp extends TokenOp {
  final List<TokenPair> pairs;
  MatchOp(this.pairs);
}

/// Calculates the difference between [unknown] and [known] token lists and creates
/// a list of token-editing operations that are needed to transform the tokens from
/// [known] to [unknown].
List<TokenOp> calculateTokenEditOps({
  required List<Token> unknown,
  required List<Token> known,
}) {
  if (unknown.isEmpty && known.isEmpty) {
    return [];
  }
  if (unknown.isEmpty) {
    return [DeleteOp(known)];
  }
  if (known.isEmpty) {
    return [InsertOp(unknown)];
  }

  final maxPrefixLength = min(unknown.length, known.length);
  final matchedPrefix = <TokenPair>[];
  for (var i = 0; i < maxPrefixLength; i++) {
    final utoken = unknown[i];
    final ktoken = known[i];
    if (!utoken.matches(ktoken)) {
      break;
    }
    matchedPrefix.add((unknown: utoken, known: ktoken));
  }

  final maxPostfixLength = maxPrefixLength - matchedPrefix.length;
  final matchedPostfix = <TokenPair>[];
  var matchedPostfixCount = 0;
  for (var i = 1; i <= maxPostfixLength; i++) {
    final utoken = unknown[unknown.length - i];
    final ktoken = known[known.length - i];
    if (!utoken.matches(ktoken)) {
      break;
    }
    matchedPostfixCount++;
  }
  for (var i = matchedPostfixCount; i >= 1; i--) {
    final utoken = unknown[unknown.length - i];
    final ktoken = known[known.length - i];
    matchedPostfix.add((unknown: utoken, known: ktoken));
  }

  List<Token> trimList(List<Token> list) {
    if (matchedPrefix.isEmpty && matchedPostfix.isEmpty) {
      return list;
    }
    return list
        .skip(matchedPrefix.length)
        .take(list.length - matchedPrefix.length - matchedPostfix.length)
        .toList();
  }

  return <TokenOp>[
    if (matchedPrefix.isNotEmpty) MatchOp(matchedPrefix),
    ..._dynamicLcs(unknown: trimList(unknown), known: trimList(known)),
    if (matchedPostfix.isNotEmpty) MatchOp(matchedPostfix),
  ];
}

List<TokenOp> _dynamicLcs({
  required List<Token> unknown,
  required List<Token> known,
}) {
  if (unknown.isEmpty && known.isEmpty) {
    return [];
  }
  if (unknown.isEmpty) {
    return [DeleteOp(known)];
  }
  if (known.isEmpty) {
    return [InsertOp(unknown)];
  }

  final m = unknown.length;
  final n = known.length;

  // table to store lengths of LCS
  final table = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (unknown[i - 1].matches(known[j - 1])) {
        table[i][j] = table[i - 1][j - 1] + 1;
      } else {
        table[i][j] = max(table[i - 1][j], table[i][j - 1]);
      }
    }
  }

  // backtrack to construct the operations
  final opsBackwards = <TokenOp>[];
  var i = m;
  var j = n;

  while (i > 0 || j > 0) {
    // shortcut: only deletes left
    if (i == 0) {
      opsBackwards.add(DeleteOp(known.take(j).toList()));
      break;
    }
    // shortcut: only inserts left
    if (j == 0) {
      opsBackwards.add(InsertOp(unknown.take(i).toList()));
      break;
    }

    bool isMatch() => i > 0 && j > 0 && table[i][j] == table[i - 1][j - 1] + 1;
    bool isInsert() => i > 0 && table[i - 1][j] >= table[i][j - 1]; // j != 0
    bool isDelete() => j > 0 && table[i - 1][j] < table[i][j - 1]; // i != 0

    if (isMatch()) {
      // match found
      final matchPairsBackwards = <TokenPair>[];
      do {
        matchPairsBackwards.add((unknown: unknown[i - 1], known: known[j - 1]));
        i--;
        j--;
      } while (isMatch());
      opsBackwards.add(MatchOp(matchPairsBackwards.reverseIfNeeded()));
    } else if (isInsert()) {
      // insert into unknown
      final insertTokens = <Token>[];
      do {
        insertTokens.add(unknown[i - 1]);
        i--;
      } while (isInsert() && !isMatch());
      opsBackwards.add(InsertOp(insertTokens.reverseIfNeeded()));
    } else {
      // delete from known
      final deleteTokens = <Token>[];
      do {
        deleteTokens.add(known[j - 1]);
        j--;
      } while (isDelete() && !isMatch());
      opsBackwards.add(DeleteOp(deleteTokens.reverseIfNeeded()));
    }
  }

  return opsBackwards.reverseIfNeeded();
}

extension _ListExt<T> on List<T> {
  List<T> reverseIfNeeded() {
    if (length <= 1) {
      return this;
    }
    return reversed.toList();
  }
}
