// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:pana/src/steps/tags.dart';

void main() {
  test('No fields', () {
    TagPattern(
      pattern: 'nnbd-compatible',
      description: 'The package is NNBD migration compatible',
    );
  });

  test('Single field', () {
    TagPattern(
      pattern: 'license:<license>',
      fields: {
        'license': 'SPDX license identifier',
      },
      description: 'License under which the package is distributed',
    );
  });

  test('No overlapping TagPattern prefixes', () {
    final uniquePrefixes =
        tagPatterns.map((p) => p.pattern.split('<').first).toSet();
    expect(uniquePrefixes.length, tagPatterns.length,
        reason: 'tagPattern prefixes are not unique');
  });

  test('match', () {
    expect(findTagPattern('license:gpl'), isNotNull);
  });

  test('bad TagPattern', () {
    expect(
      () => TagPattern(
        pattern: 'lic',
        fields: {
          'license': 'SPDX license identifier',
        },
        description: 'License under which the package is distributed',
      ),
      throwsArgumentError,
    );

    expect(
      () => TagPattern(
        pattern: 'license:<license>',
        description: 'License under which the package is distributed',
      ),
      throwsArgumentError,
    );

    expect(
      () => TagPattern(
        pattern: '#license',
        description: 'License under which the package is distributed',
      ),
      throwsArgumentError,
    );
  });
}
