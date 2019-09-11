// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart' show sealed;
import 'package:file/file.dart';
import 'result.dart' show ResultBuilder, BreakStep;

export 'result.dart' show ResultBuilder, BreakStep;

@sealed
class Step {
  /// Unique name of this analysis step.
  ///
  /// This **must** be a unique lowercase identifier matching `^[a-z0-9_-]+$`.
  final String name;

  /// Run analysis given an [AnalysisContext].
  ///
  /// This may throw [BreakStep] to report a final suggestion and stop analysis.
  final Future<void> Function(AnalysisContext) run;

  Step(this.name, this.run);
}

/// Context passed to [Step] which allows access to resources during analysis.
@sealed
class AnalysisContext {
  AnalysisContext({this.packageFolder, this.add});

  /// A [ResultBuilder] to which results for the current package can be added.
  final ResultBuilder add;

  /// [Directory] containing the extracted package.
  ///
  /// This is provided through the `package:file` interface.
  ///
  /// Note: Future version of this may be read-only, do not write to this
  /// file-system.
  final Directory packageFolder;
}
