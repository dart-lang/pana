// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/steps/common/changelog.dart' show changelog;

import '../descriptor.dart' as d;
import '../steptest.dart';

void main() {
  stepTest('Passes with good CHANGELOG.md',
      steps: [changelog],
      package: [
        d.pubspec({
          'name': 'subject',
          'version': '1.0.0',
          'dependencies': {},
          'environment': {
            'sdk': '>=2.0.0 <3.0.0',
          },
        }),
        d.file('CHANGELOG.md', '''
# 1.0.0
 * Initial release
'''),
      ],
      tags: isEmpty,
      kinds: isEmpty);

  stepTest('Detect missing entry in CHANGELOG.md',
      steps: [changelog],
      package: [
        d.pubspec({
          'name': 'subject',
          'version': '1.0.0',
          'dependencies': {},
          'environment': {
            'sdk': '>=2.0.0 <3.0.0',
          },
        }),
        d.file('CHANGELOG.md', '''
# 0.9.1
 * Some old release...
'''),
      ],
      tags: isEmpty,
      kinds: allOf([
        contains('changelog-entry-missing'),
        hasLength(1),
      ]));

  stepTest('detect missing CHANGELOG',
      steps: [changelog],
      package: [
        d.pubspec({
          'name': 'subject',
          'version': '1.0.0',
          'dependencies': {},
          'environment': {
            'sdk': '>=2.0.0 <3.0.0',
          },
        }),
      ],
      tags: isEmpty,
      kinds: allOf([
        contains('changelog-not-found'),
        hasLength(1),
      ]));
}
