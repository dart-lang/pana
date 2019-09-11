// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/local.dart' show LocalFileSystem;
import 'package:matcher/matcher.dart' show Matcher, anything;
import 'package:pana/src/steps/run.dart';
import 'package:pana/src/steps/step.dart';
import 'package:test/test.dart' show test, expect;

import 'descriptor.dart' show Descriptor;

export 'package:matcher/matcher.dart';

/// Test a set of [steps] against [package].
///
/// The [tags] matcher will be matched against the set of tags produced.
/// The [kinds] matchers will be matched against the set of `kind` supplied when
/// errors, warnings and hints were created.
void stepTest(
  String testName, {
  List<Step> steps,
  List<Descriptor> package,
  Matcher tags = anything,
  Matcher kinds = anything,
}) {
  final stepNames = steps.map((s) => s.name).join(',');
  test('$testName ($stepNames)', () async {
    final fs = const LocalFileSystem();
    final tempFolder = await fs.systemTempDirectory.createTemp('pana-test-');
    try {
      // Create contents of package in [tempFolder]
      await Future.wait(package.map((d) => d.create(tempFolder)));

      // Run the analysis
      final result = await run(tempFolder.path, steps);

      expect(result.tags, tags);
      expect(
        result.suggestions
            .map((s) => s.code.split('.').skip(1).join('.'))
            .toSet(),
        kinds,
      );
    } finally {
      await tempFolder.delete(recursive: true);
    }
  });
}
