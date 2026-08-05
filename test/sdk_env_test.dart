// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/sdk_env.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  test('parsing SDK version', () {
    final version =
        'Dart VM version: 2.0.0-dev.49.0 (Wed Apr 18 20:41:36 2018 +0200) on "macos_x64"';
    final sdkInfo = DartSdkInfo.parse(version);
    expect(sdkInfo.version, Version.parse('2.0.0-dev.49.0'));
    expect(sdkInfo.dateString, 'Wed Apr 18 20:41:36 2018 +0200');
    expect(sdkInfo.platform, 'macos_x64');
  });

  test('parsing SDK version  new style', () {
    final version =
        'Dart VM version: 2.8.0-edge.b8b4a16179653c18f49bc31abab016595a1245b2 (be) (Fri Mar 27 10:16:29 2020 +0000) on "linux_x64"';
    final sdkInfo = DartSdkInfo.parse(version);
    expect(
      sdkInfo.version,
      Version.parse('2.8.0-edge.b8b4a16179653c18f49bc31abab016595a1245b2'),
    );
    expect(sdkInfo.dateString, 'Fri Mar 27 10:16:29 2020 +0000');
    expect(sdkInfo.platform, 'linux_x64');
  });

  test('parsing SDK version newest style', () {
    final version =
        'Dart SDK version: 2.15.0-edge.e8ddc0219f1e8f1ad784143fec693890e2b81954 (be) (Fri Aug 13 13:27:41 2021 +0000) on "macos_x64"';
    final sdkInfo = DartSdkInfo.parse(version);
    expect(
      sdkInfo.version,
      Version.parse('2.15.0-edge.e8ddc0219f1e8f1ad784143fec693890e2b81954'),
    );
    expect(sdkInfo.dateString, 'Fri Aug 13 13:27:41 2021 +0000');
    expect(sdkInfo.platform, 'macos_x64');
  });

  test('fail to parse', () {
    expect(() => DartSdkInfo.parse('-'), throwsA(isA<FormatException>()));
    expect(
      () => DartSdkInfo.parse(
        'Dart VM version: 2.0.0.0 (Wed Apr 18 20:41:36 2018 +0200) on "macos_x64"',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'filesNeedingFormat handles dangling symlink analysis_options.yaml safely',
    () async {
      final toolEnv = await ToolEnvironment.create();
      await withTempDir((dir) async {
        final outsideDir = await Directory.systemTemp.createTemp('outside_');
        try {
          final outsideTarget = p.join(outsideDir.path, 'canary.txt');
          final symlink = Link(p.join(dir, 'analysis_options.yaml'));
          await symlink.create(outsideTarget);

          final pubspec = File(p.join(dir, 'pubspec.yaml'));
          await pubspec.writeAsString('''
name: test_pkg
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
''');
          final libDir = Directory(p.join(dir, 'lib'))..createSync();
          File(
            p.join(libDir.path, 'test_pkg.dart'),
          ).writeAsStringSync('void main() {}\n');

          expect(await File(outsideTarget).exists(), isFalse);

          await toolEnv.filesNeedingFormat(dir, false);

          // Target file outside should not be created.
          expect(await File(outsideTarget).exists(), isFalse);
        } finally {
          await outsideDir.delete(recursive: true);
        }
      });
    },
  );
}
