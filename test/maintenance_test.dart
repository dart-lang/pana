// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:pana/src/download_utils.dart';
import 'package:pana/src/maintenance.dart';
import 'package:pana/src/model.dart';
import 'package:pana/src/package_analyzer.dart' show InspectOptions;
import 'package:pana/src/pubspec.dart';

final _withIssuesJson = {
  "missingChangelog": true,
  "missingExample": true,
  "missingReadme": true,
  "missingAnalysisOptions": true,
  "oldAnalysisOptions": false,
  "strongModeEnabled": true,
  "isExperimentalVersion": true,
  "isPreReleaseVersion": true,
  "dartdocSuccessful": false,
  "suggestions": [
    {
      'code': 'pubspec.sdk.missing',
      'level': 'error',
      'title': 'Add SDK constraint in `pubspec.yaml`.',
      'description':
          'For information about setting SDK constraint, please see [https://www.dartlang.org/tools/pub/pubspec#sdk-constraints](https://www.dartlang.org/tools/pub/pubspec#sdk-constraints).',
      'score': 50.0,
    },
    {
      'code': 'platform.conflict.inPkg',
      'level': 'error',
      'title': 'Fix platform conflicts.',
      'description': 'conflict description',
      'score': 20.0,
    },
    {
      'code': 'dartdoc.aborted',
      'level': 'error',
      'title': 'Running `dartdoc` failed.',
      'description': 'Make sure `dartdoc` runs without any issues.',
      'score': 10.0,
    },
    {
      'code': 'readme.missing',
      'level': 'warning',
      'title': 'Maintain `README.md`.',
      'description':
          'Readme should inform others about your project, what it does, and how they can use it.',
      'score': 30.0,
    },
    {
      'code': 'changelog.missing',
      'level': 'warning',
      'title': 'Maintain `CHANGELOG.md`.',
      'description':
          'Changelog entries help clients to follow the progress in your code.',
      'score': 20.0,
    },
    {
      'code': 'pubspec.dependencies.unconstrained',
      'level': 'warning',
      'title': 'Use constrained dependencies.',
      'description':
          'The `pubspec.yaml` contains 1 dependency without version constraints. Specify version ranges for the following dependencies: `foo`.',
      'score': 20.0,
    },
    {
      'code': 'pubspec.description.tooShort',
      'level': 'warning',
      'title': 'Add `description` in `pubspec.yaml`.',
      'description':
          'Description is critical to giving users a quick insight into the features of the package and why it is relevant to their query. Ideal length is between 60 and 180 characters.',
      'score': 20.0,
    },
    {
      'code': 'pubspec.homepage.isNotHelpful',
      'level': 'warning',
      'title': 'Homepage is not helpful.',
      'description':
          'Update the `homepage` property: create a website about the package or use the source repository URL.',
      'score': 10.0,
    },
    {
      'code': 'example.missing',
      'level': 'hint',
      'title': 'Maintain an example.',
      'description':
          'Create a short demo in the `example/` directory to show how to use this package. Common file name patterns include: `main.dart`, `example.dart` or you could also use `sandbox.dart`.',
      'score': 10.0,
    },
    {
      'code': 'packageVersion.preV01',
      'level': 'hint',
      'title': 'Package is pre-v0.1 release.',
      'description':
          'While there is nothing inherently wrong with versions of `0.0.*`, it usually means that the author is still experimenting with the general direction of the API.',
      'score': 10.0
    },
    {
      'code': 'packageVersion.preRelease',
      'level': 'hint',
      'title': 'Package is pre-release.',
      'description':
          'Pre-release versions should be used with caution, their API may change in breaking ways.',
      'score': 5.0,
    }
  ]
};

final _perfect = Maintenance(
  missingChangelog: false,
  missingReadme: false,
  missingExample: false,
  missingAnalysisOptions: false,
  oldAnalysisOptions: false,
  strongModeEnabled: true,
  isExperimentalVersion: false,
  isPreReleaseVersion: false,
  dartdocSuccessful: true,
);

final _withIssues = Maintenance.fromJson(_withIssuesJson);

void main() {
  group('detectMaintenance', () {
    test('empty directory', () async {
      final maintenance = await detectMaintenance(
        InspectOptions(),
        UrlChecker(),
        d.sandbox,
        Pubspec.fromJson({'name': 'sandbox', 'version': '0.0.1-alpha'}),
        [
          PkgDependency(
            package: 'foo',
            dependencyType: 'direct',
            constraintType: 'empty',
            constraint: null,
            resolved: null,
            available: null,
            errors: null,
          )
        ],
        pkgPlatform: DartPlatform.conflict('conflict description'),
        dartdocSuccessful: false,
      );

      expect(json.decode(json.encode(maintenance.toJson())), _withIssuesJson);
    });
  });

  group('getMaintenanceScore', () {
    test('with issues', () {
      expect(calculateMaintenanceScore(_withIssues), 0.0);
    });

    test('perfect', () {
      expect(calculateMaintenanceScore(_perfect), 1.0);
    });

    group('publish date affects score', () {
      final expectedScores = {
        -1: 1.0, // possible for time issues to be off – treated as 'now'
        0: 1.0,
        1: 1.0,
        365: 1.0,
        (365 * 1.5).toInt(): 0.50,
        365 * 2: 0.0
      };

      for (var offset in expectedScores.keys) {
        test("from $offset days ago", () {
          final age = offset == null ? null : Duration(days: offset);
          final expectedScore = expectedScores[offset];

          Matcher matcher;
          if (expectedScore == expectedScore.toInt().toDouble()) {
            // we expect an exact match
            matcher = equals(expectedScore);
          } else {
            // we expect a close match
            matcher = closeTo(expectedScore, 0.01);
          }

          expect(calculateMaintenanceScore(_perfect, age: age), matcher);
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
      expect(suggestion.score, closeTo(52.05, 0.01));
    });

    test('age: two and half years', () {
      final suggestion = getAgeSuggestion(const Duration(days: 910));
      expect(suggestion, isNotNull);
      expect(suggestion.title, 'Package is too old.');
      expect(suggestion.level, 'warning');
      expect(suggestion.score, 100.0);
    });
  });
}
