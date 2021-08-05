import 'package:pana/src/third_party/diff_match_patch/test.dart';

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
  testDiffLevenshtein();
  testWordDiffLevenshtein();
  testCleanupEfficiency();
}
