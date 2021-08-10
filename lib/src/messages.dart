// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class _MsgDict {
  final String dartanalyzerShortName;
  final String dartanalyzerShortCmd;
  final String dartfmtShortName;
  final String dartfmtShortCmd;

  _MsgDict._({
    this.dartanalyzerShortName = 'dart analyze',
    this.dartanalyzerShortCmd = 'dart analyze .',
    this.dartfmtShortName = 'dart format',
    this.dartfmtShortCmd = 'dart format .',
  });

  static _MsgDict defaultDict = _MsgDict._();

  static _MsgDict flutterDict = _MsgDict._(
    dartanalyzerShortName: 'flutter analyze',
    dartanalyzerShortCmd: 'flutter analyze',
    dartfmtShortName: 'flutter format',
    dartfmtShortCmd: 'flutter format',
  );
}

String runningDartanalyzerFailed(bool usesFlutter, errorMsg) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return 'Running `${dict.dartanalyzerShortCmd}` failed with the following output:\n\n'
      '```\n$errorMsg\n```\n';
}
