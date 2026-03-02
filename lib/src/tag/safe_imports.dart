// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';

/// Maps dart: library URIs to their safe symbols.
const _safeSymbolsByLibrary = {
  /// Symbols from dart:io that are safe to use on all platforms
  /// because they don't require actual IO operations.
  'dart:io': {
    'ContentType',
    'Cookie',
    'HeaderValue',
    'HttpDate',
    'HttpHeaders',
    'HttpStatus',
  },
};

/// Checks if a namespace directive (import/export) only uses safe symbols
/// from an otherwise platform-specific library.
///
/// Returns `true` if:
/// - The directive has at least one `show` combinator
/// - All shown symbols are in the safe list for that library
/// - The directive has no `hide` combinators (for simpler rules)
///
/// Returns `false` otherwise, including when:
/// - The dependency is not a restricted library with safe symbols
/// - The directive has no combinators (imports everything)
/// - The directive has `hide` combinators
/// - Any shown symbol is not in the safe list
bool isSafeImport(NamespaceDirective directive, Uri dependency) {
  final safeSymbols = _safeSymbolsByLibrary[dependency.toString()];
  if (safeSymbols == null) {
    return false;
  }

  // Must have at least one `show` combinator
  final showCombinators = directive.combinators
      .whereType<ShowCombinator>()
      .toList();
  if (showCombinators.isEmpty) {
    return false;
  }

  // Must not have any `hide` combinators (too complex to analyze)
  if (directive.combinators.any((c) => c is HideCombinator)) {
    return false;
  }

  // Check all shown symbols from all `show` combinators
  for (final combinator in showCombinators) {
    for (final identifier in combinator.shownNames) {
      if (!safeSymbols.contains(identifier.name)) {
        return false;
      }
    }
  }

  return true;
}
