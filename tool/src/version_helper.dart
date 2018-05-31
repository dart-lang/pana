// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/type.dart';
import 'package:json_serializable/type_helper.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_gen/source_gen.dart';

class VersionHelper extends TypeHelper {
  final _checker = new TypeChecker.fromRuntime(Version);

  String serialize(
      DartType targetType, String expression, SerializeContext context) {
    if (!_checker.isExactlyType(targetType)) {
      return null;
    }
    var nullThing = context.nullable ? '?' : '';
    return "$expression$nullThing.toString()";
  }

  String deserialize(
      DartType targetType, String expression, DeserializeContext context) {
    if (!_checker.isExactlyType(targetType)) {
      return null;
    }
    var value = 'new Version.parse($expression as String)';
    if (context.nullable) {
      value = '$expression == null ? null : $value';
    }
    return value;
  }
}

class VersionConstraintHelper extends TypeHelper {
  final _checker = new TypeChecker.fromRuntime(VersionConstraint);

  String serialize(
      DartType targetType, String expression, SerializeContext context) {
    if (!_checker.isExactlyType(targetType)) {
      return null;
    }
    var nullThing = context.nullable ? '?' : '';
    return "$expression$nullThing.toString()";
  }

  String deserialize(
      DartType targetType, String expression, DeserializeContext context) {
    if (!_checker.isExactlyType(targetType)) {
      return null;
    }
    var value = 'new VersionConstraint.parse($expression as String)';
    if (context.nullable) {
      value = '$expression == null ? null : $value';
    }
    return value;
  }
}
