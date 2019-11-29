// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/tag_detection.dart';
import 'package:test/test.dart';

class FakeLibraryGraph implements LibraryGraph {
  final Map<String, Set<String>> successors = {};
  FakeLibraryGraph();
  @override
  Set<Uri> directSuccessors(Uri uri) {
    return successors[uri.toString()].map(Uri.parse).toSet();
  }
}

main() {
  final graph = FakeLibraryGraph();
  graph.successors['dart:async'] = {};
  graph.successors['dart:io'] = {};
  graph.successors['dart:html'] = {};
  graph.successors['native_helper.dart'] = {'dart:async', 'dart:io'};
  graph.successors['native_main.dart'] = {'native_helper.dart'};
  graph.successors['web_helper.dart'] = {'dart:async', 'dart:html'};

  graph.successors['cyclic1.dart'] = {'cyclic2.dart', 'dart:async'};
  graph.successors['cyclic2.dart'] = {'cyclic2.dart', 'web_helper.dart'};
  graph.successors['cyclic_main.dart'] = {'cyclic1.dart'};

  test('succeeds on ok graph', () async {
    expect(
        RuntimeSupport(graph, Runtime.nativeAot)
            .findRuntimeViolation(Uri.parse('native_main.dart'))
            .hasPath,
        false);
  });
  test('fails with counter-example', () {
    expect(
        RuntimeSupport(graph, Runtime.web)
            .findRuntimeViolation(Uri.parse('native_main.dart')),
        PathResult<Uri>.path([
          'native_main.dart',
          'native_helper.dart',
          'dart:io'
        ].map(Uri.parse).toList()));
  });
  test('handles cycles', () {
    expect(
        RuntimeSupport(graph, Runtime.web)
            .findRuntimeViolation(Uri.parse('cyclic_main.dart')),
        PathResult<Uri>.noPath());
    expect(
        RuntimeSupport(graph, Runtime.nativeAot)
            .findRuntimeViolation(Uri.parse('cyclic_main.dart')),
        PathResult<Uri>.path([
          'cyclic_main.dart',
          'cyclic1.dart',
          'cyclic2.dart',
          'web_helper.dart',
          'dart:html',
        ].map(Uri.parse).toList()));
  });
}
