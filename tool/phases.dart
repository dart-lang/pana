// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/type.dart';
import 'package:build_runner/build_runner.dart';
import 'package:json_serializable/generators.dart';
import 'package:json_serializable/type_helper.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_gen/source_gen.dart';

final PhaseGroup phases = new PhaseGroup.singleAction(
    new GeneratorBuilder([
      new JsonSerializableGenerator.withDefaultHelpers([new VersionHelper()])
    ]),
    new InputSet('pana', const [
      'lib/src/*.dart',
    ]));

class VersionHelper extends TypeHelper {
  final _checker = new TypeChecker.fromRuntime(Version);

  String serialize(DartType targetType, String expression, _, __) {
    if (!_checker.isExactlyType(targetType)) {
      return null;
    }

    return "$expression?.toString()";
  }

  String deserialize(DartType targetType, String expression, _, __) {
    if (!_checker.isExactlyType(targetType)) {
      return null;
    }

    return '$expression == null ? null : new Version.parse($expression)';
  }
}
