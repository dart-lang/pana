// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/model.dart';
import 'package:test/test.dart';

void main() {
  group('PanaRuntimeInfo', () {
    test('no Flutter SDK', () {
      final info = PanaRuntimeInfo(panaVersion: '1.0.0', sdkVersion: '2.0.0');
      expect(info.hasFlutter, isFalse);
      expect(info.flutterVersion, isNull);
      expect(info.flutterInternalDartSdkVersion, isNull);
    });

    test('no build', () {
      final info = PanaRuntimeInfo(
        panaVersion: '1.0.0',
        sdkVersion: '2.0.0',
        flutterVersions: {
          'frameworkVersion': '2.1.0-13.0.pre.292',
          'channel': 'master',
          'repositoryUrl': 'https://github.com/flutter/flutter',
          'frameworkRevision': 'b60c855af5150b695638b2195f500d3c003b71ab',
          'frameworkCommitDate': '2021-03-26 22:14:01 -0700',
          'engineRevision': 'b5e15d055d135c5b82feb3263f47f9f9a038343e',
          'dartSdkVersion': '2.13.0',
          'flutterRoot': '/bin/flutter',
        },
      );
      expect(info.hasFlutter, isTrue);
      expect(info.flutterVersion, '2.1.0-13.0.pre.292');
      expect(info.flutterInternalDartSdkVersion, '2.13.0');
    });

    test('full build', () {
      final info = PanaRuntimeInfo(
        panaVersion: '1.0.0',
        sdkVersion: '2.0.0',
        flutterVersions: {
          'frameworkVersion': '2.1.0-13.0.pre.292',
          'channel': 'master',
          'repositoryUrl': 'https://github.com/flutter/flutter',
          'frameworkRevision': 'b60c855af5150b695638b2195f500d3c003b71ab',
          'frameworkCommitDate': '2021-03-26 22:14:01 -0700',
          'engineRevision': 'b5e15d055d135c5b82feb3263f47f9f9a038343e',
          'dartSdkVersion': '2.13.0 (build 2.13.0-162.0.dev)',
          'flutterRoot': '/bin/flutter',
        },
      );
      expect(info.hasFlutter, isTrue);
      expect(info.flutterVersion, '2.1.0-13.0.pre.292');
      expect(info.flutterInternalDartSdkVersion, '2.13.0-162.0.dev');
    });
  });
}
