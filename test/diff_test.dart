import 'package:pana/src/third_party/diff_match_patch/test.dart';

// The follwing test cases were forked from the google's diff-match-patch
// dart library and hence the actual tests are in a separate "third_-party"
// directory and we only call those tests from here.
void main() {
  testDiffCommonPrefix();
  testDiffCommonSuffix();
  testDiffCommonOverlap();
  testDiffMain();
  testDiffHalfMatch();
  testDiffLineToChars();
  testDiffCharsToLines();
  testDiffCleanupMerge();
  testDiffCleanupSemanticLosses();
  testDiffCleanupSemantic();
  testDiffBisect();
  testWordDiffLevenshtein();
  testCleanupEfficiency();
}
