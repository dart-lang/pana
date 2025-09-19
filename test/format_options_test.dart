// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart';
import 'package:pana/src/utils.dart';
import 'package:test/test.dart';

import 'env_utils.dart';

void main() {
  group('Format option extracted from dev-dependency lint', () {
    late TestEnv testEnv;

    setUpAll(() async {
      testEnv = await TestEnv.createTemp(
        proxyPublishCutoff: DateTime(2025, 09, 16),
      );
    });

    tearDownAll(() async {
      await testEnv.close();
    });

    test('package with transient formatting rule', () async {
      await withTempDir((path) async {
        final builder = PackageDirBuilder(path);
        await builder.writePubspec(
          devDependencies: {'pedantic_mono': '1.33.0'},
        );

        Future<void> expectFormatting({
          required String code,
          required bool include,
          required bool hasIssue,
        }) async {
          await builder.writeFile('lib/code.dart', code);
          await builder.writeFile(
            'analysis_options.yaml',
            include
                ? 'include: package:pedantic_mono/analysis_options.yaml'
                : '',
          );
          final rs = await testEnv.inspectDir(path);
          expect(
            rs.report!.sections
                .firstWhere((s) => s.id == ReportSectionId.analysis)
                .summary,
            hasIssue
                ? contains('match the Dart formatter')
                : isNot(contains('match the Dart formatter')),
          );
        }

        await expectFormatting(
          code: "final x = ['a'];\n",
          include: false,
          hasIssue: false,
        );
        await expectFormatting(
          code: "final x = ['a'];\n",
          include: true,
          hasIssue: false,
        );
        await expectFormatting(
          code: "final x = ['a',];\n",
          include: false,
          hasIssue: true,
        );
        await expectFormatting(
          code: "final x = [\n  'a',\n];\n",
          include: true,
          hasIssue: false,
        );
      });
    });
  });
}
