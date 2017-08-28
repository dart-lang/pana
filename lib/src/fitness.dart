// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.health;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:json_serializable/annotations.dart';
import 'package:path/path.dart' as p;

import 'analyzer_output.dart';
import 'platform.dart';
import 'summary.dart';

part 'fitness.g.dart';

/// Describes a health metric that takes size and complexity into account.
/// It can be displayed in the form of [value] out of [total].
@JsonSerializable()
class Fitness extends Object with _$FitnessSerializerMixin {
  /// The current fitness score.
  final double value;

  /// The maximum score, representing the size and complexity of the library.
  final double total;

  Fitness(this.value, this.total);

  factory Fitness.fromJson(Map json) => _$FitnessFromJson(json);
}

Future<Fitness> calcFitness(
    String pkgDir,
    String dartFile,
    bool isFormatted,
    List<AnalyzerOutput> fileAnalyzerItems,
    List<String> directLibs,
    PlatformInfo platform) async {
  // statement count estimated by:
  // - counting the non-comment ';' characters
  // - counting the non-empty lines
  // - assumed average line length
  var content = await new File(p.join(pkgDir, dartFile)).readAsString();
  content = content
      .replaceAll(_blockCommentRegExp, '')
      .replaceAll(_lineCommentRegExp, '');
  final semiColonCount = content.replaceAll(_antiSemiColonRegExp, '').length;
  final nonEmptyLineCount =
      content.split('\n').where((line) => line.trim().isNotEmpty).length;
  final statementEstimate = content.length ~/ 40;
  final statementCount =
      (semiColonCount + nonEmptyLineCount + statementEstimate) ~/ 3;

  // code magnitude is estimated by the imported lib count and statement count
  final total =
      max(1.0, ((directLibs?.length ?? 0) + statementCount).toDouble());

  // major issues are penalized in the percent of the total
  // minor issues are penalized in a fixed amount
  final errorPoints = max(10.0, total * 0.20); // 20%
  final warnPoints = max(4.0, total * 0.05); // 5%
  final hintPoints = 1.0;

  var penalties = 0.0;

  if (platform != null && platform.hasConflict) {
    penalties += errorPoints;
  }

  if (!isFormatted) {
    penalties += hintPoints;
  }

  if (fileAnalyzerItems != null) {
    for (var item in fileAnalyzerItems) {
      if (item.type.startsWith('INFO')) {
        penalties += hintPoints;
      } else if (item.type.startsWith('WARN')) {
        penalties += warnPoints;
      } else {
        penalties += errorPoints;
      }
    }
  }

  final score = max(0.0, total - penalties);
  return new Fitness(score, total);
}

Fitness calcPkgFitness(
    Iterable<DartFileSummary> files, List<AnalyzerIssue> issues) {
  var total = 0.0;
  var value = 0.0;
  for (var dfs in files) {
    if (dfs.isInLib && dfs.fitness != null) {
      total += dfs.fitness.total;
      value += dfs.fitness.value;
    }
  }
  total = max(1.0, total);

  // major tool errors are penalized in the percent of the total
  final toolErrorPoints = max(20.0, total * 0.20); // 20%
  value -= issues.length * toolErrorPoints;

  return new Fitness(max(0.0, value), total);
}

final _blockCommentRegExp = new RegExp(r'\/\*.*\*\/', multiLine: true);
final _lineCommentRegExp = new RegExp(r'\/\/.*$');
final _antiSemiColonRegExp = new RegExp(r'[^\;]');
