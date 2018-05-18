// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:build/build.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';

class PackageVersionBulder extends Builder {
  @override
  Future build(BuildStep buildStep) async {
    var content = await buildStep
        .readAsString(new AssetId(buildStep.inputId.package, 'pubspec.yaml'));

    var yaml = loadYaml(content) as Map;

    var versionString = yaml['version'] as String;
    versionString = new Version.parse(versionString).toString();

    var versionFileId =
        new AssetId(buildStep.inputId.package, 'lib/src/version.dart');

    await buildStep.writeAsString(versionFileId, '''
$copyrightHeader
import 'package:pub_semver/pub_semver.dart';

final panaPkgVersion = new Version.parse("$versionString");
''');
  }

  @override
  Map<String, List<String>> get buildExtensions => const {
        r'$lib$': const ['src/version.dart']
      };
}

final copyrightHeader =
    '''// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

${defaultFileHeader.trim()}
''';
