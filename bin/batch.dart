#!/usr/bin/env dart --checked
// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/command_runner.dart';

import 'package:pana/src/batch/batch_compare_command.dart';
import 'package:pana/src/batch/batch_query_command.dart';

/// Batch analysis and comparison tool.
///
/// 1. Select packages with the query tool:
///
///       dart bin/batch query dart:sdk
///       dart bin/batch query --sort popularity --limit 10
///       dart bin/batch query --sort updated --max-age-days 14
///       dart bin/batch query --output output.txt
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
///    The `analysisOptions` file must be self-containaing, `include` is not supported.
///
/// 4. Run batch compare:
///
///       dart bin/batch compare --packages packages.txt --experiment experiment.yaml
///       dart bin/batch compare --package comma,separated,package,list --control old.yaml --experiment new.yaml --output output.json
///
Future<void> main(List<String> args) async {
  final runner = CommandRunner('batch',
      'Runs analysis on multiple packages and compares granted score impact.')
    ..addCommand(BatchQueryCommand())
    ..addCommand(BatchCompareCommand());
  await runner.run(args);
}
