#!/usr/bin/env dart --checked
// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/command_runner.dart';

import 'package:pana/src/batch/batch_compare_command.dart';
import 'package:pana/src/batch/batch_query_command.dart';
import 'package:pana/src/batch/batch_run_command.dart';

/// Batch analysis and comparison tool.
///
/// 1. Select packages with the query tool:
///
///       dart bin/batch.dart query dart:sdk
///       dart bin/batch.dart query --sort popularity --limit 10
///       dart bin/batch.dart query --sort updated --max-age-days 14
///       dart bin/batch.dart query --output output.txt
///
/// 2. Merge selected packages into a .txt file, one package per line.
///
/// 3. Prepare experimental (and control) configuration:
///
///       # experimental.yaml (everything is optional)
///       dartSdk: '/path/to/dart/sdk'
///       flutterSdk: '/path/to/flutter/sdk'
///       environment:
///         FLUTTER_ROOT: '/path...'
///       analysisOptions: local-file.yaml
///
///    The `analysisOptions` parameter may be an URL if it starts with https://
///    The `analysisOptions` file must be self-containing, `include` is not supported.
///
/// 4. Run batch compare:
///
///       dart bin/batch.dart compare --packages packages.txt --experiment experiment.yaml
///       dart bin/batch.dart compare --package comma,separated,package,list --control old.yaml --experiment new.yaml --output output.json
///
///    Or run a single config:
///
///       dart bin/batch.dart run --packages packages.txt --config config.yaml
Future<void> main(List<String> args) async {
  final runner =
      CommandRunner<void>(
          'batch',
          'Runs analysis on multiple packages and compares granted score impact.',
        )
        ..addCommand(BatchQueryCommand())
        ..addCommand(BatchCompareCommand())
        ..addCommand(BatchRunCommand());
  await runner.run(args);
}
