# Diff-Match-Patch

This code was forked from Google's [diff-match-patch](https://github.com/google/diff-match-patch) library.

## Modifications made in code

- Code was updated for modern Dart naming standards and language features.
- `diff` - Code related to diff functionality was retained and ported to [null-safety](https://dart.dev/null-safety) along with linting.
- `Levenshtein distance` - Levenshtein distance which was calculated initially based on the number of characters modified was altered to calculate based on the number of words modified.

## Source

Repository - [link](https://github.com/google/diff-match-patch)
Git revision - [a6367d7](https://github.com/google/diff-match-patch/commit/a6367d7866833ac037fbdefcdbcbee4def86e326)
