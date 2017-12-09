// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/maintenance.dart';
import 'package:pana/src/summary.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

const _withIssuesJson = const {
  "missingChangelog": true,
  "missingReadme": true,
  "missingAnalysisOptions": true,
  "oldAnalysisOptions": false,
  "strongModeEnabled": false,
  "isExperimentalVersion": true,
  "isPreReleaseVersion": true,
  "errorCount": 1,
  "warningCount": 3,
  "hintCount": 1
};

final _perfect = new Maintenance(
    missingChangelog: false,
    missingReadme: false,
    missingAnalysisOptions: false,
    oldAnalysisOptions: false,
    strongModeEnabled: true,
    isExperimentalVersion: false,
    isPreReleaseVersion: false,
    errorCount: 0,
    warningCount: 0,
    hintCount: 0);

final _withIssues = new Maintenance.fromJson(_withIssuesJson);

void main() {
  group('detectMaintenance', () {
    test('empty directory', () async {
      final suggestions = <Suggestion>[
        new Suggestion.error('error', 'error'),
        new Suggestion.warning('warning', 'warning'),
        new Suggestion.hint('hint', 'hint'),
      ];
      final maintenance = await detectMaintenance(
          d.sandbox, new Version(0, 1, 0, pre: 'alpha'), suggestions);

      expect(maintenance.toJson(), _withIssuesJson);

      expect(suggestions.map((s) => s.level),
          ['error', 'warning', 'hint', 'warning', 'warning']);
    });
  });
  group('getMaintenanceScore', () {
    final now = new DateTime(2018);
    group('publish date affects score', () {
      final expectedScores = {
        -1: 1.0, // possible for time issues to be off – treated as 'now'
        0: 1.0,
        1: 1.0,
        365: 1.0,
        (365 * 1.5).toInt(): 0.5013,
        365 * 2: 0.0
      };

      for (var offset in expectedScores.keys) {
        test("from $offset days ago", () {
          final publishDate = now.subtract(new Duration(days: offset));

          final expectedScore = expectedScores[offset];

          Matcher matcher;
          if (expectedScore == expectedScore.toInt().toDouble()) {
            // we expect an exact match
            matcher = equals(expectedScore);
          } else {
            // we expect a close match
            matcher = closeTo(expectedScore, 0.01);
          }

          expect(_perfect.getMaintenanceScore(publishDate, now: now), matcher);

          // Also test the `withIssues` version, which is scaled down due to
          // issues
          final issueScore = expectedScore * 0.5486865725436479;
          if (issueScore == issueScore.toInt().toDouble()) {
            // we expect an exact match
            matcher = equals(issueScore);
          } else {
            // we expect a close match
            matcher = closeTo(issueScore, 0.01);
          }

          expect(
              _withIssues.getMaintenanceScore(publishDate, now: now), matcher);
        });
      }
    });
  });
}
