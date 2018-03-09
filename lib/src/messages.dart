// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class _MsgDict {
  final String dartanalyzerShortName;
  final String dartanalyzerShortCmd;
  final String dartfmtShortName;
  final String dartfmtShortCmd;

  _MsgDict._({
    this.dartanalyzerShortName: 'dartanalyzer',
    this.dartanalyzerShortCmd: 'dartanalyzer .',
    this.dartfmtShortName: 'dartfmt',
    this.dartfmtShortCmd: 'dartfmt -n .',
  });

  static _MsgDict defaultDict = new _MsgDict._();

  static _MsgDict flutterDict = new _MsgDict._(
    dartanalyzerShortName: 'flutter analyze',
    dartanalyzerShortCmd: 'flutter analyze',
    dartfmtShortName: 'flutter format',
    dartfmtShortCmd: 'flutter format',
  );
}

String runDartfmtToFormatFile(bool usesFlutter, String dartFile) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return 'Run `${dict.dartfmtShortName}` to format `$dartFile`.';
}

String makeSureDartfmtRuns(bool usesFlutter) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return 'Make sure `${dict.dartfmtShortName}` runs.';
}

String runningDartfmtFailed(bool usesFlutter, errorMsg) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return 'Running `${dict.dartfmtShortCmd}` failed with the following output:\n\n'
      '```\n$errorMsg\n```\n';
}

String makeSureDartanalyzerRuns(bool usesFlutter) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return 'Make sure `${dict.dartanalyzerShortName}` runs.';
}

String runningDartanalyzerFailed(bool usesFlutter, errorMsg) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return 'Running `${dict.dartanalyzerShortCmd}` failed with the following output:\n\n'
      '```\n$errorMsg\n```\n';
}
