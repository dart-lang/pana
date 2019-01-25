// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class _MsgDict {
  final String dartanalyzerShortName;
  final String dartanalyzerShortCmd;
  final String dartfmtShortName;
  final String dartfmtShortCmd;

  _MsgDict._({
    this.dartanalyzerShortName = 'dartanalyzer',
    this.dartanalyzerShortCmd = 'dartanalyzer .',
    this.dartfmtShortName = 'dartfmt',
    this.dartfmtShortCmd = 'dartfmt -n .',
  });

  static _MsgDict defaultDict = _MsgDict._();

  static _MsgDict flutterDict = _MsgDict._(
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
  return "Make sure `${dict.dartfmtShortName}` successfully runs on your package's source files.";
}

String runningDartfmtFailed(bool usesFlutter, errorMsg) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return 'Running `${dict.dartfmtShortCmd}` failed with the following output:\n\n'
      '```\n$errorMsg\n```\n';
}

String makeSureDartanalyzerRuns(bool usesFlutter) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return "Make sure `${dict.dartanalyzerShortName}` successfully runs on your package's source files.";
}

String runningDartanalyzerFailed(bool usesFlutter, errorMsg) {
  final dict = usesFlutter ? _MsgDict.flutterDict : _MsgDict.defaultDict;
  return 'Running `${dict.dartanalyzerShortCmd}` failed with the following output:\n\n'
      '```\n$errorMsg\n```\n';
}

/// Build a list like "A, B and 3 more".
String buildSample(Iterable<String> items) {
  final total = items.length;
  final fullCount = total <= 3 ? total : 2;
  var sample = items.take(fullCount).join(', ');
  if (total > fullCount) {
    sample = '$sample and ${total - fullCount} more.';
  }
  return sample;
}

String pluralizeCount(int count, String name) {
  if (count <= 0) {
    return null;
  } else if (count == 1) {
    return '$count $name';
  } else {
    return '$count ${name}s';
  }
}

String formatIssueCounts(int errorCount, int warningCount, int hintCount) {
  final reportParts = <String>[
    pluralizeCount(errorCount, 'error'),
    pluralizeCount(warningCount, 'warning'),
    pluralizeCount(hintCount, 'hint'),
  ];
  reportParts.removeWhere((s) => s == null);
  return reportParts.join(', ');
}
