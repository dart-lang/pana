// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.analyzer_output;

import 'package:path/path.dart' as p;
import 'package:quiver/core.dart';
import 'package:source_gen/generators/json_serializable.dart';

part 'analyzer_output.g.dart';

@JsonSerializable()
class AnalyzerOutput extends Object
    with _$AnalyzerOutputSerializerMixin
    implements Comparable<AnalyzerOutput> {
  static final _regexp = new RegExp('^' + // beginning of line
          '([\\w_\\.]+)\\|' * 3 + // first three error notes
          '([^\\|]+)\\|' + // file path
          '([\\w_\\.]+)\\|' * 3 + // line, column, length
          '(.*?)' + // rest is the error message
          '\$' // end of line
      );

  final String type;
  final String file;
  final int line;
  final int col;
  final String error;

  AnalyzerOutput(this.type, this.error, this.file, this.line, this.col);

  static AnalyzerOutput parse(String content, {String projectDir}) {
    if (content.isEmpty) {
      throw new ArgumentError('Provided content is empty.');
    }
    var matches = _regexp.allMatches(content).toList();

    if (matches.isEmpty) {
      if (content.endsWith(" is a part and cannot be analyzed.")) {
        var filePath = content.split(' ').first;

        content = content.replaceAll(filePath, '').trim();

        if (projectDir != null) {
          assert(p.isWithin(projectDir, filePath));
          filePath = p.relative(filePath, from: projectDir);
        }

        return new AnalyzerOutput('WEIRD', content, filePath, 0, 0);
      }

      if (content == "Please pass in a library that contains this part.") {
        return null;
      }

      throw new ArgumentError(
          'Provided content does not align with expectations.\n`$content`');
    }

    var match = matches.single;

    var type = [match[1], match[2], match[3]].join('|');

    var filePath = match[4];
    var line = match[5];
    var column = match[6];
    // length = 7
    var error = match[8];

    if (projectDir != null) {
      assert(p.isWithin(projectDir, filePath));
      filePath = p.relative(filePath, from: projectDir);
    }

    return new AnalyzerOutput(
        type, error, filePath, int.parse(line), int.parse(column));
  }

  factory AnalyzerOutput.fromJson(Map<String, dynamic> json) =>
      _$AnalyzerOutputFromJson(json);

  @override
  int compareTo(AnalyzerOutput other) {
    var myVals = _values;
    var otherVals = other._values;
    for (var i = 0; i < myVals.length; i++) {
      var compare = (_values[i] as Comparable).compareTo(otherVals[i]);

      if (compare != 0) {
        return compare;
      }
    }

    assert(this == other);

    return 0;
  }

  @override
  int get hashCode => hashObjects(_values);

  @override
  bool operator ==(Object other) {
    if (other is AnalyzerOutput) {
      var myVals = _values;
      var otherVals = other._values;
      for (var i = 0; i < myVals.length; i++) {
        if (myVals[i] != otherVals[i]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  List<Object> get _values => [file, line, col, type, error];
}
