// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:pana/src/tag/_graphs.dart';
import 'package:pana/src/tag/_specs.dart';
import 'package:pana/src/tag/tagger.dart';
import 'package:pana/src/tag/_violations.dart';

class FakeLibraryGraph implements LibraryGraph {
  final Map<String, Set<String>> successors = {};
  FakeLibraryGraph();
  @override
  Set<Uri> directSuccessors(Uri uri) {
    return successors[uri.toString()]!.map(Uri.parse).toSet();
  }
}

void main() {
  group('path finding', () {
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
          runtimeViolationFinder(graph, Runtime.nativeAot, (p) => null)
              .findPath(Uri.parse('native_main.dart'))
              .hasPath,
          false);
    });
    test('fails with counter-example', () {
      expect(
          runtimeViolationFinder(graph, Runtime.web, (p) => null)
              .findPath(Uri.parse('native_main.dart'))
              .path,
          ['native_main.dart', 'native_helper.dart', 'dart:io']
              .map(Uri.parse)
              .toList());
    });
    test('handles cycles', () {
      expect(
          runtimeViolationFinder(graph, Runtime.web, (p) => null)
              .findPath(Uri.parse('cyclic_main.dart'))
              .hasPath,
          false);
      expect(
          runtimeViolationFinder(graph, Runtime.nativeAot, (p) => null)
              .findPath(Uri.parse('cyclic_main.dart'))
              .path,
          [
            'cyclic_main.dart',
            'cyclic1.dart',
            'cyclic2.dart',
            'web_helper.dart',
            'dart:html',
          ].map(Uri.parse).toList());
    });
  });
}
