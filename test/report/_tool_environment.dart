// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:pana/pana.dart';

Future<ToolEnvironment> testToolEnvironment() async {
  final fakeFlutterRoot =
      d.dir('fake_flutter_root', [d.file('version', '2.0.0')]);
  await fakeFlutterRoot.create();
  return ToolEnvironment.fake(
    dartCmd: [Platform.resolvedExecutable],
    pubCmd: [Platform.resolvedExecutable, 'pub'],
    environment: {'FLUTTER_ROOT': fakeFlutterRoot.io.path},
    runtimeInfo: PanaRuntimeInfo(
      panaVersion: '1.2.3',
      sdkVersion: '2.12.0',
      flutterVersions: {
        'frameworkVersion': '2.0.0',
        'channel': 'stable',
        'repositoryUrl': 'https://github.com/flutter/flutter',
        'frameworkRevision': '13c6ad50e980cad1844457869c2b4c5dc3311d03',
        'frameworkCommitDate': '2021-02-19 10:03:46 +0100',
        'engineRevision': 'b04955656c87de0d80d259792e3a0e4a23b7c260',
        'dartSdkVersion': '2.12.0 (build 2.12.0)',
        'flutterRoot': fakeFlutterRoot.io.path
      },
    ),
  );
}
