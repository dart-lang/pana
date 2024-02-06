// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

class PubEntry {
  static final _headerMatch = RegExp(r'^([A-Z]{2,4})[ ]{0,2}: (.*)');
  static final _lineMatch = RegExp(r'^    \|(.*)');

  final String header;
  final List<String> content;

  PubEntry(this.header, this.content);

  static Iterable<PubEntry> parse(String input) sync* {
    String? header;
    List<String>? entryLines;

    for (var line in LineSplitter.split(input)) {
      if (line.trim().isEmpty) {
        continue;
      }
      var match = _headerMatch.firstMatch(line);

      if (match != null) {
        if (header != null || entryLines != null) {
          assert(entryLines!.isNotEmpty);
          yield PubEntry(header!, entryLines!);
          header = null;
          entryLines = null;
        }
        header = match[1];
        entryLines = <String>[match[2]!];
      } else {
        match = _lineMatch.firstMatch(line);

        if (match == null) {
          // Likely due to Flutter silly
          // log.severe("Could not parse pub line `$line`.");
          continue;
        }

        assert(entryLines != null);
        entryLines!.add(match[1]!);
      }
    }

    if (header != null || entryLines != null) {
      assert(entryLines!.isNotEmpty);
      yield PubEntry(header!, entryLines!);
      header = null;
      entryLines = null;
    }
  }

  @override
  String toString() => '$header: ${content.join('\n')}';
}
