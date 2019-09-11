// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show UnmodifiableListView;
import 'package:file/chroot.dart' show ChrootFileSystem;
import 'package:file/local.dart' show LocalFileSystem;

import 'common/changelog.dart' show changelog;
import 'result.dart' show ResultBuilder, Result, BreakStep;
import 'step.dart';

/// List of all steps from `common/` and `flutter/`.
final List<Step> steps = UnmodifiableListView([
  changelog,
]);

/// Run [steps] on [packageFolder] and return [Result].
Future<Result> run(
  String packageFolder,
  Iterable<Step> steps,
) async {
  ArgumentError.checkNotNull(packageFolder, 'packageFolder');
  ArgumentError.checkNotNull(steps, 'steps');

  final packageFs = ChrootFileSystem(const LocalFileSystem(), packageFolder);

  try {
    final rbs = <ResultBuilder>[];
    for (final step in steps) {
      final rb = ResultBuilder(step.name);
      rbs.add(rb);
      try {
        await step.run(AnalysisContext(
          packageFolder: packageFs.directory('/'),
          add: rb,
        ));
      } on BreakStep catch (e) {
        e.report(rb);
      }
    }
    return ResultBuilder.build(rbs);
  } finally {
    // Cleanup stuff
  }
}
