// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build_runner/build_runner.dart';
import 'package:json_serializable/generators.dart';
import 'package:source_gen/source_gen.dart';

import 'version_generator.dart';
import 'version_helper.dart';

final PhaseGroup phases = new PhaseGroup.singleAction(
    new PartBuilder([
      new JsonSerializableGenerator.withDefaultHelpers([new VersionHelper()]),
      new PackageVersionGenerator()
    ]),
    new InputSet('pana', const [
      'lib/src/analyzer_output.dart',
      'lib/src/license.dart',
      'lib/src/platform.dart',
      'lib/src/pub_summary.dart',
      'lib/src/summary.dart',
      'lib/src/version.dart',
    ]));
