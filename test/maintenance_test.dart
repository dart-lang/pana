// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:pana/src/maintenance.dart';
import 'package:pana/src/model.dart';
import 'package:pana/src/pubspec.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

final _withIssuesJson = {
  "missingChangelog": true,
  "missingExample": true,
  "missingReadme": true,
  "missingAnalysisOptions": true,
  "oldAnalysisOptions": false,
  "strongModeEnabled": false,
  "isExperimentalVersion": true,
  "isPreReleaseVersion": true,
  "dartdocSuccessful": false,
  "errorCount": 1,
  "warningCount": 1,
  "hintCount": 1,
  "suggestions": [
    {
      'code': 'platform.conflict.inPkg',
      'level': 'error',
      'title': 'Fix platform conflicts.',
      'description': 'conflict description',
      'penalty': {'amount': 0, 'fraction': 2000}
    },
    {
      'code': 'dartdoc.aborted',
      'level': 'error',
      'title': 'Running `dartdoc` failed.',
      'description': 'Make sure `dartdoc` runs without any issues.',
      'penalty': {'amount': 0, 'fraction': 1000},
    },
    {
      'code': 'errorCode',
      'level': 'error',
      'title': 'error',
      'description': 'error'
    },
    {
      'code': 'changelog.missing',
      'level': 'warning',
      'title': 'Maintain `CHANGELOG.md`.',
      'description':
          'Changelog entries help clients to follow the progress in your code.',
      'penalty': {'amount': 0, 'fraction': 2000}
    },
    {
      'code': 'pubspec.homepage.doesNotExists',
      'level': 'warning',
      'title': 'Homepage does not exists.',
      'description':
          'We were unable to access `null` at the time of the analysis.',
      'penalty': {'amount': 0, 'fraction': 1000},
    },
    {
      'code': 'pubspec.dependencies.unconstrained',
      'level': 'warning',
      'title': 'Use constrained dependencies.',
      'description':
          'The `pubspec.yaml` contains 1 dependency without version constraints. Specify version ranges for the following dependencies: `foo`.',
      'penalty': {'amount': 0, 'fraction': 500}
    },
    {
      'code': 'pubspec.description.tooShort',
      'level': 'warning',
      'title': 'Add `description` in `pubspec.yaml`.',
      'description':
          'Description is critical to giving users a quick insight into the features of the package and why it is relevant to their query. Ideal length is between 60 and 180 characters.',
      'penalty': {'amount': 0, 'fraction': 500}
    },
    {
      'code': 'readme.missing',
      'level': 'warning',
      'title': 'Maintain `README.md`.',
      'description':
          'Readme should inform others about your project, what it does, and how they can use it.',
      'penalty': {'amount': 0, 'fraction': 500}
    },
    {
      'code': 'packageVersion.preRelease',
      'level': 'hint',
      'title': 'Package is pre-release.',
      'description':
          'Pre-release versions should be used with caution, their API may change in breaking ways.',
      'penalty': {'amount': 0, 'fraction': 200}
    },
    {
      'code': 'packageVersion.preV1',
      'level': 'hint',
      'title': 'Package is pre-v1 release.',
      'description':
          'While there is nothing inherently wrong with versions of `0.*.*`, it usually means that the author is still experimenting with the general direction API.',
      'penalty': {'amount': 10, 'fraction': 0}
    },
    {
      'code': 'example.missing',
      'level': 'hint',
      'title': 'Maintain an example.',
      'description':
          'Create a short demo in the `example/` directory to show how to use this package. Common file name patterns include: `main.dart`, `example.dart` or you could also use `sandbox.dart`.',
      'penalty': {'amount': 5, 'fraction': 0}
    },
  ]
};

final _perfect = new Maintenance(
    missingChangelog: false,
    missingReadme: false,
    missingExample: false,
    missingAnalysisOptions: false,
    oldAnalysisOptions: false,
    strongModeEnabled: true,
    isExperimentalVersion: false,
    isPreReleaseVersion: false,
    dartdocSuccessful: true,
    errorCount: 0,
    warningCount: 0,
    hintCount: 0);

final _withIssues = new Maintenance.fromJson(_withIssuesJson);

void main() {
  group('detectMaintenance', () {
    test('empty directory', () async {
      final suggestions = <Suggestion>[
        new Suggestion.error('errorCode', 'error', 'error'),
        new Suggestion.warning('warningCode', 'warning', 'warning'),
        new Suggestion.hint('hintCode', 'hint', 'hint'),
      ];
      final maintenance = await detectMaintenance(
        d.sandbox,
        new Pubspec.fromJson({'name': 'sandbox', 'version': '0.1.0-alpha'}),
        suggestions,
        [new PkgDependency('foo', 'direct', 'empty', null, null, null, null)],
        pkgPlatform: new DartPlatform.conflict('conflict description'),
        dartdocSuccessful: false,
      );

      expect(json.decode(json.encode(maintenance.toJson())), _withIssuesJson);
    });
  });

  group('getMaintenanceScore', () {
    test('with issues', () {
      expect(getMaintenanceScore(_withIssues), closeTo(0.434, 0.001));
    });

    test('perfect', () {
      expect(getMaintenanceScore(_perfect), 1);
    });

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
          final age = offset == null ? null : new Duration(days: offset);
          final expectedScore = expectedScores[offset];

          Matcher matcher;
          if (expectedScore == expectedScore.toInt().toDouble()) {
            // we expect an exact match
            matcher = equals(expectedScore);
          } else {
            // we expect a close match
            matcher = closeTo(expectedScore, 0.01);
          }

          expect(getMaintenanceScore(_perfect, age: age), matcher);
        });
      }
    });
  });

  group('Age-based suggestion', () {
    test('young package', () {
      expect(getAgeSuggestion(const Duration(days: 10)), isNull);
    });

    test('age: one and half years', () {
      final suggestion = getAgeSuggestion(const Duration(days: 555));
      expect(suggestion, isNotNull);
      expect(suggestion.title, 'Package is getting outdated.');
      expect(suggestion.level, 'hint');
      expect(suggestion.penalty.amount, 0);
      expect(suggestion.penalty.fraction, 5205);
    });

    test('age: two and half years', () {
      final suggestion = getAgeSuggestion(const Duration(days: 910));
      expect(suggestion, isNotNull);
      expect(suggestion.title, 'Package is too old.');
      expect(suggestion.level, 'warning');
      expect(suggestion.penalty.amount, 10000);
      expect(suggestion.penalty.fraction, 0);
    });
  });
}
