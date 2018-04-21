#!/usr/bin/env dart --checked
// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(kevmoo): document how to run this file in README.md

import 'package:build_runner/build_runner.dart';
import 'package:build_config/build_config.dart';
import 'package:json_serializable/json_serializable.dart';
import 'package:source_gen/source_gen.dart';

import 'src/version_generator.dart';
import 'src/version_helper.dart';

main(List<String> args) => run(args, _builders);

final _builders = <BuilderApplication>[
  applyToRoot(
      new PartBuilder([
        new JsonSerializableGenerator.withDefaultHelpers([
          new VersionHelper(),
          new VersionConstraintHelper(),
        ]),
        new PackageVersionGenerator()
      ], header: _copyrightHeader),
      generateFor: const InputSet(include: const [
        'pubspec.yaml',
        'lib/src/analyzer_output.dart',
        'lib/src/fitness.dart',
        'lib/src/license.dart',
        'lib/src/maintenance.dart',
        'lib/src/model.dart',
        'lib/src/pub_summary.dart',
        'lib/src/version.dart',
      ]))
];

final _copyrightHeader =
    '''// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

$defaultFileHeader
''';
