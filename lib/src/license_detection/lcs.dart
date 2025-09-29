// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:math';

import 'license_detector.dart' show Token;

/// A pair representing matching tokens from unknown to known sequences.
typedef TokenPair = ({Token unknown, Token known});

/// Calculates the longest common subsequence (LCS) between [unknown] and [known] token lists.
///
/// Tokens are compared using their normalized [Token.value]. Returns the longest
/// common subsequence as a list of [TokenPair] objects containing references to
/// both the unknown and known tokens that match.
List<TokenPair> longestCommonSubsequence({
  required List<Token> unknown,
  required List<Token> known,
}) {
  final maxPrefixLength = min(unknown.length, known.length);
  if (maxPrefixLength == 0) {
    return [];
  }

  final matchedPrefix = <TokenPair>[];
  for (var i = 0; i < maxPrefixLength; i++) {
    final utoken = unknown[i];
    final ktoken = known[i];
    if (utoken.value != ktoken.value) {
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
    if (utoken.value != ktoken.value) {
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

  return [
    ...matchedPrefix,
    ..._dynamicLcs(unknown: trimList(unknown), known: trimList(known)),
    ...matchedPostfix,
  ];
}

Iterable<TokenPair> _dynamicLcs({
  required List<Token> unknown,
  required List<Token> known,
}) {
  if (unknown.isEmpty || known.isEmpty) {
    return [];
  }
  final m = unknown.length;
  final n = known.length;

  // table to store lengths of LCS
  final table = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (unknown[i - 1].value == known[j - 1].value) {
        table[i][j] = table[i - 1][j - 1] + 1;
      } else {
        table[i][j] = max(table[i - 1][j], table[i][j - 1]);
      }
    }
  }

  // backtrack to construct the sequence
  final matchesBackwards = <TokenPair>[];
  var i = m;
  var j = n;

  while (i > 0 && j > 0) {
    if (unknown[i - 1].value == known[j - 1].value) {
      // building backwards, will need to reverse the list
      matchesBackwards.add((unknown: unknown[i - 1], known: known[j - 1]));
      i--;
      j--;
    } else if (table[i - 1][j] > table[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }
  return matchesBackwards.reversed;
}
