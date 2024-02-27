// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:pana/src/tool/flutter_tool.dart';
import 'package:test/test.dart';

void main() {
  group('Intermittent messages', () {
    final jsonOutput =
        const JsonEncoder.withIndent('  ').convert({'key': 'value'});

    test('unchanged text', () {
      expect(stripIntermittentFlutterMessages(jsonOutput), jsonOutput);
    });

    test('waiting for another process', () {
      expect(
        stripIntermittentFlutterMessages(
            'Waiting for another flutter process to complete.\n$jsonOutput'),
        jsonOutput,
      );
    });

    test('welcome screen', () {
      expect(
        stripIntermittentFlutterMessages(
            '$jsonOutput\n\n$_welcomeScreenOutput'),
        jsonOutput,
      );
    });
  });
}

final _welcomeScreenOutput =
    '''  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                 Welcome to Flutter! - https://flutter.dev                  ║
  ║                                                                            ║
  ║ The Flutter tool uses Google Analytics to anonymously report feature usage ║
  ║ statistics and basic crash reports. This data is used to help improve      ║
  ║ Flutter tools over time.                                                   ║
  ║                                                                            ║
  ║ Flutter tool analytics are not sent on the very first run. To disable      ║
  ║ reporting, type 'flutter config --no-analytics'. To display the current    ║
  ║ setting, type 'flutter config'. If you opt out of analytics, an opt-out    ║
  ║ event will be sent, and then no further information will be sent by the    ║
  ║ Flutter tool.                                                              ║
  ║                                                                            ║
  ║ By downloading the Flutter SDK, you agree to the Google Terms of Service.  ║
  ║ The Google Privacy Policy describes how data is handled in this service.   ║
  ║                                                                            ║
  ║ Moreover, Flutter includes the Dart SDK, which may send usage metrics and  ║
  ║ crash reports to Google.                                                   ║
  ║                                                                            ║
  ║ Read about data we send with crash reports:                                ║
  ║ https://flutter.dev/docs/reference/crash-reporting                         ║
  ║                                                                            ║
  ║ See Google's privacy policy:                                               ║
  ║ https://policies.google.com/privacy                                        ║
  ║                                                                            ║
  ║ To disable animations in this tool, use                                    ║
  ║ 'flutter config --no-cli-animations'.                                      ║
  ╚════════════════════════════════════════════════════════════════════════════╝
''';
