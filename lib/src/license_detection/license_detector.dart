// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:pana/src/third_party/diff_match_patch/diff.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

part 'confidence.dart';
part 'crc32.dart';
part 'license.dart';
part 'primary_filter.dart';
part 'token_matcher.dart';
part 'tokenizer.dart';

// Load corpus licenses.
final _licenses = loadLicensesFromDirectories(_directories);

class Result {
  /// Licenses detected in the input text.
  ///
  /// The list is empty if no licenses are detected.
  final List<LicenseMatch> matches;

  /// Percentage of tokens in the unknown license that were not claimed in any of the license matches.
  final double unclaimedTokenPercentage;

  /// The count of the longest sequence of token in the input
  /// text that was not a part of any detected license.
  final int longestUnclaimedTokenCount;

  Result(this.matches, this.unclaimedTokenPercentage,
      this.longestUnclaimedTokenCount);
}

/// Returns an instance of [Result] for every license in the corpus detected
/// in the unknown text with a confidence greater than [threshold].
Result detectLicense(String text, double threshold) {
  final granularity = computeGranularity(threshold);

  final unknownLicense = LicenseWithNGrams.parse(
      License.parse(identifier: '', content: text), granularity);

  final possibleLicenses = filter(unknownLicense.tokenFrequency, _licenses)
      .map((e) => LicenseWithNGrams.parse(e, granularity));
  var result = <LicenseMatch>[];

  for (var license in possibleLicenses) {
    final matches = findPotentialMatches(
      unknownLicense,
      license,
      threshold,
    );

    for (var match in matches) {
      try {
        final hit = licenseMatch(unknownLicense, license, match, threshold);
        result.add(hit);
      } on LicenseMismatchException catch (_) {
        // print(e.toString());
      }
    }
  }

  result = removeDuplicates(result);
  result.sort(sortOnConfidence);
  result = removeOverLappingMatches(result);
  final unclaimedPercentage =
      claculateUnclaimedTokenPercentage(result, unknownLicense.tokens.length);
  final longestUnclaimedTokenCount =
      findLongestUnclaimedTokenRange(result, unknownLicense.tokens.length);
  return Result(List.unmodifiable(result), unclaimedPercentage,
      longestUnclaimedTokenCount);
}

/// Returns the minimum number of token runs that must match according to
/// [threshold] to be able to consider it as match.
///
/// In a worst case scenario where the error is evenly
/// distributed (breaking the token runs most times), if we
/// consider 100 tokens and threshold 0.8, we'll have
/// 4 continuos matching tokens and a mismatch.
///
/// So this function returns the minimum number of tokens
/// or 1 (which is greater) to consider them as part
/// of known license text.
@visibleForTesting
int computeGranularity(double threshold) {
  if (threshold > 0.9) {
    return 10; // avoid divide by 0
  }

  return max(1, threshold ~/ (1 - threshold));
}

/// For [LicenseMatch] in [matches] having the same `spdx-identifier` the one with highest confidence
/// is considered and rest are discared.
@visibleForTesting
List<LicenseMatch> removeDuplicates(List<LicenseMatch> matches) {
  var identifierToLicense = <String, LicenseMatch>{};

  for (var match in matches) {
    if (identifierToLicense.containsKey(match.identifier)) {
      var prevMatch = identifierToLicense[match.identifier];
      // As both the licenses are same consider tha max of tokens claimed among these two.
      var tempMatch =
          prevMatch!.confidence > match.confidence ? prevMatch : match;

      tempMatch = tempMatch.updateTokenIndex(
        min(prevMatch.tokenRange.start, match.tokenRange.start),
        max(prevMatch.tokenRange.end, match.tokenRange.end),
      );

      identifierToLicense[match.identifier] = tempMatch;
      continue;
    }

    identifierToLicense[match.identifier] = match;
  }

  return identifierToLicense.values.toList();
}

/// Custom comparator to the sort the licenses based on decreasing order of confidence.
///
/// Incase the confidence detected is same for the matches, ratio of tokens claimed
/// in the unkown text to the number of tokens present in the known license text
/// is considered
@visibleForTesting
int sortOnConfidence(LicenseMatch matchA, LicenseMatch matchB) {
  if (matchA.confidence > matchB.confidence) {
    return -1;
  }

  if (matchA.confidence < matchB.confidence) {
    return 1;
  }

  final matchATokensPercent =
      matchA.tokensClaimed / matchA.license.tokens.length;
  final matchBTokensPercent =
      matchB.tokensClaimed / matchB.license.tokens.length;

  return (matchATokensPercent > matchBTokensPercent) ? -1 : 1;
}

/// Fliters out licenses having overlapping ranges giving preferences to a match with higher token density.
///
/// Token density is the product of number of tokens claimed in the range and
/// confidence score of the match. Incase of exact match we retain both
/// the matches so that the user can resolve them.
@visibleForTesting
List<LicenseMatch> removeOverLappingMatches(List<LicenseMatch> matches) {
  var retain = List.filled(matches.length, false);
  var retainedmatches = <LicenseMatch>[];

  // We consider token density to retain matches of larger licenses
  // having lesser confidence when compared to a smaller license
  // haing a  perfect match.
  for (var i = 0; i < matches.length; i++) {
    var keep = true;
    final matchA = matches[i];
    final rangeA = Range(matchA.tokenRange.start, matchA.tokenRange.end);

    var proposals = <int, bool>{};
    for (var j = 0; j < matches.length; j++) {
      if (j == i) {
        break;
      }
      final matchB = matches[j];
      final rangeB = Range(matchB.tokenRange.start, matchB.tokenRange.end);
      // Check if matchA is larger license containing an insatnce of
      // smaller license within it and decide to whether retain it
      // or not by comapring their token densities. Example NPL
      // contains MPL.
      if (rangeA.contains(rangeB) && retain[j]) {
        final aConf = matchA.tokensClaimed * matchA.confidence;
        final bConf = matchB.tokensClaimed * matchB.confidence;

        // Retain both the licenses incase of a exact match,
        // so that it can be resolved by the user.
        if (aConf > bConf) {
          proposals[j] = true;
        } else if (bConf > aConf) {
          keep = false;
        }
      } else if (rangeA.overlapsWith(rangeB)) {
        keep = false;
      }
    }

    if (keep) {
      retain[i] = true;
      proposals.forEach((key, value) {
        retain[key] = value;
      });
    }
  }

  for (var i = 0; i < matches.length; i++) {
    if (retain[i]) {
      retainedmatches.add(matches[i]);
    }
  }

  return retainedmatches;
}

/// Returns the ratio of tokens claimed in all the matches to the number of
/// tokens present in the unknown license.
///
/// Minimum possible score is 0 incase none of the known licenses are detected.
/// The maximum score can be greater than 1 in cases where the same range of
/// tokens is claimed for two licenses.
///
/// For example NPL contains MPL in this case we detect 2 licenses in the
/// same range and hence we have a possibilty of getting a score
/// than 1.
double claculateUnclaimedTokenPercentage(
    List<LicenseMatch> matches, int unknownTokensCount) {
  var claimedTokenCount = 0;

  for (var match in matches) {
    claimedTokenCount += match.tokensClaimed;
  }

  return max(0, (unknownTokensCount - claimedTokenCount) / unknownTokensCount);
}

const _directories = ['third_party/spdx/licenses'];

/// Returns the number of tokens in the longest unclaimed token
/// sequence.
int findLongestUnclaimedTokenRange(List<LicenseMatch> matches, int end) {
  var ranges = <Range>[];
  if (matches.isEmpty) return end;

  for (var match in matches) {
    ranges.add(Range(match.tokenRange.start, match.tokenRange.end));
  }

  ranges.sort(sortRangeOnStartValue);
  var maxTokenSequence = ranges.first.start - 0;

  for (var i = 1; i < ranges.length; i++) {
    maxTokenSequence =
        max(ranges[i].start - ranges[i - 1].end, maxTokenSequence);
  }

  maxTokenSequence = max(maxTokenSequence, end - ranges.last.end);
  return maxTokenSequence;
}

int sortRangeOnStartValue(Range a, Range b) => a.start - b.start;

void main() {
  final result = detectLicense(text, 0.95);
  print('results');
  print(result.longestUnclaimedTokenCount);
  print(result.unclaimedTokenPercentage);
  print(result.matches.length);
  print(result.matches.first.tokenRange.start);
  print(result.matches.first.tokenRange.end);
}

const text = '''                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "{}"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright {yyyy} {name of copyright owner}

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
''';
