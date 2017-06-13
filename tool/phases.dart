// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:build_runner/build_runner.dart';

import 'package:source_gen/generators/json_serializable_generator.dart' as json;
import 'package:source_gen/source_gen.dart';

final PhaseGroup phases = new PhaseGroup.singleAction(
    new GeneratorBuilder(const [const json.JsonSerializableGenerator()]),
    new InputSet('pana', const [
      'lib/src/analyzer_output.dart',
      'lib/src/platform.dart',
      'lib/src/pub_summary.dart'
    ]));
