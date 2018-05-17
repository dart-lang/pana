// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:build/build.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

class PackageVersionBulder extends Builder {
  @override
  Future build(BuildStep buildStep) async {
    var content =
        await buildStep.readAsString(new AssetId.parse('pana|pubspec.yaml'));

    var yaml = loadYaml(content) as Map;

    var versionString = yaml['version'] as String;
    versionString = new Version.parse(versionString).toString();

    var versionFileId = new AssetId('pana', 'lib/src/version.dart');

    // Write out the new asset.
    await buildStep.writeAsString(versionFileId, '''
// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.version;

import 'package:pub_semver/pub_semver.dart';

final panaPkgVersion = new Version.parse("$versionString");
''');
  }

  @override
  Map<String, List<String>> get buildExtensions => const {
        r'$lib$': const ['src/version.dart']
      };
}
