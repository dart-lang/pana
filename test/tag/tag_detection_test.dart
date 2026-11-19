// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/tag/_common.dart';
import 'package:pana/src/tag/_graphs.dart';
import 'package:pana/src/tag/_violations.dart';
import 'package:pana/src/tag/tagger.dart';
import 'package:test/test.dart';

class FakeLibraryGraph implements LibraryGraph {
  final Map<String, Set<String>> successors = {};
  FakeLibraryGraph();
  @override
  Set<Uri> directSuccessors(Uri uri) {
    return successors[uri.toString()]!.map(Uri.parse).toSet();
  }
}

final class _CountingGraph<T> implements DirectedGraph<T> {
  final Map<T, Set<T>> edges;
  final successorCalls = <T, int>{};
  T? throwOnNode;

  _CountingGraph(this.edges);

  @override
  Set<T> directSuccessors(T node) {
    successorCalls[node] = (successorCalls[node] ?? 0) + 1;
    if (throwOnNode == node) {
      throw TagException('boom at $node');
    }
    return edges[node] ?? const {};
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
        runtimeViolationFinder(
          graph,
          Runtime.nativeAot,
          (p) => null,
        ).findPath(Uri.parse('native_main.dart')).hasPath,
        false,
      );
    });
    test('fails with counter-example', () {
      expect(
        runtimeViolationFinder(
          graph,
          Runtime.web,
          (p) => null,
        ).findPath(Uri.parse('native_main.dart')).path,
        [
          'native_main.dart',
          'native_helper.dart',
          'dart:io',
        ].map(Uri.parse).toList(),
      );
    });
    test('handles cycles', () {
      expect(
        runtimeViolationFinder(
          graph,
          Runtime.web,
          (p) => null,
        ).findPath(Uri.parse('cyclic_main.dart')).hasPath,
        false,
      );
      expect(
        runtimeViolationFinder(
          graph,
          Runtime.nativeAot,
          (p) => null,
        ).findPath(Uri.parse('cyclic_main.dart')).path,
        [
          'cyclic_main.dart',
          'cyclic1.dart',
          'cyclic2.dart',
          'web_helper.dart',
          'dart:html',
        ].map(Uri.parse).toList(),
      );
    });

    test('memoizes verified-safe subgraphs across calls', () {
      final countingGraph = _CountingGraph<String>({
        'a': {'shared'},
        'b': {'shared'},
        'shared': {'leaf'},
        'leaf': {},
      });
      final predicateCalls = <String, int>{};
      final finder = PathFinder<String>(countingGraph, (node) {
        predicateCalls[node] = (predicateCalls[node] ?? 0) + 1;
        return null;
      });

      expect(finder.findPath('a').hasPath, false);
      expect(finder.findPath('b').hasPath, false);
      expect(finder.findPath('shared').hasPath, false);

      expect(predicateCalls['shared'], 1);
      expect(predicateCalls['leaf'], 1);
      expect(countingGraph.successorCalls['shared'], 1);
      expect(countingGraph.successorCalls['leaf'], 1);
    });

    test(
      'continues searching remaining branches after hitting cached safe node',
      () {
        for (final children in [
          {'shared_safe', 'bad_branch'},
          {'bad_branch', 'shared_safe'},
        ]) {
          final countingGraph = _CountingGraph<String>({
            'safe_root': {'shared_safe'},
            'shared_safe': {'safe_leaf'},
            'safe_leaf': {},
            'mixed_root': children,
            'bad_branch': {'violation'},
            'violation': {},
          });
          final finder = PathFinder<String>(
            countingGraph,
            (node) => node == 'violation' ? (_) => null : null,
          );

          expect(finder.findPath('safe_root').hasPath, false);
          final result = finder.findPath('mixed_root');
          expect(result.hasPath, true);
          expect(result.path, ['mixed_root', 'bad_branch', 'violation']);
        }
      },
    );

    test('caches violation paths across calls without cycles', () {
      final countingGraph = _CountingGraph<String>({
        'r1': {'mid'},
        'r2': {'mid'},
        'r3': {'r2'},
        'c1': {'c2', 'mid'},
        'c2': {'c1'},
        'mid': {'violation'},
        'violation': {},
      });
      final predicateCalls = <String, int>{};
      final finder = PathFinder<String>(countingGraph, (node) {
        predicateCalls[node] = (predicateCalls[node] ?? 0) + 1;
        return node == 'violation'
            ? (path) => Explanation('bad', path.join('->'), tag: 't')
            : null;
      });

      expect(finder.findPath('r1').path, ['r1', 'mid', 'violation']);
      expect(finder.findPath('r2').path, ['r2', 'mid', 'violation']);
      expect(finder.findViolation('r3')?.explanation, 'r3->r2->mid->violation');
      expect(finder.findPath('c2').path, ['c2', 'c1', 'mid', 'violation']);
      expect(finder.findPath('violation').path, ['violation']);

      expect(predicateCalls['mid'], 1);
      expect(predicateCalls['violation'], 1);
      expect(countingGraph.successorCalls['mid'], 1);
    });

    test('does not mark cyclic node safe when violation is found', () {
      // DFS pops from the end of directSuccessors.toList(), so placing 'b'
      // after 'violation' makes 'a' explore 'b' -> 'a' (cycle) first, finish
      // 'b', and then find 'violation'. 'b' can still reach 'violation' via 'a'.
      final countingGraph = _CountingGraph<String>({
        'a': {'violation', 'b'},
        'b': {'a'},
        'violation': {},
      });
      final finder = PathFinder<String>(
        countingGraph,
        (node) => node == 'violation' ? (_) => null : null,
      );

      expect(finder.findPath('a').path, ['a', 'violation']);
      expect(finder.findPath('b').path, ['b', 'a', 'violation']);
    });

    test('memoizes cyclic safe graphs', () {
      final countingGraph = _CountingGraph<String>({
        'a': {'b'},
        'b': {'a'},
        'c': {'a'},
      });
      final finder = PathFinder<String>(countingGraph, (_) => null);

      expect(finder.findPath('a').hasPath, false);
      expect(finder.findPath('c').hasPath, false);
      expect(countingGraph.successorCalls['a'], 1);
      expect(countingGraph.successorCalls['b'], 1);
    });

    test('does not cache safe nodes when traversal throws', () {
      final countingGraph = _CountingGraph<String>({
        'a': {'b'},
        'b': {'violation'},
        'violation': {},
      })..throwOnNode = 'b';
      final finder = PathFinder<String>(
        countingGraph,
        (node) => node == 'violation' ? (_) => null : null,
      );

      expect(() => finder.findPath('a'), throwsA(isA<TagException>()));
      countingGraph.throwOnNode = null;
      expect(finder.findPath('a').path, ['a', 'b', 'violation']);
    });
  });
}
