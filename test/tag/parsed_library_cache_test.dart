// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/analysis/uri_converter.dart';
import 'package:pana/src/tag/_common.dart';
import 'package:pana/src/tag/_graphs.dart';
import 'package:pana/src/tag/_specs.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../package_descriptor.dart';

final class _CountingAnalysisSession implements AnalysisSession {
  final AnalysisSession _inner;
  final parseCounts = <String, int>{};

  _CountingAnalysisSession(this._inner);

  @override
  UriConverter get uriConverter => _inner.uriConverter;

  @override
  SomeParsedUnitResult getParsedUnit(String path) {
    parseCounts[path] = (parseCounts[path] ?? 0) + 1;
    return _inner.getParsedUnit(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ParsedLibraryCache', () {
    test(
      'parses each file at most once across runtime configurations',
      () async {
        final descriptor = d.dir('cache', [
          packageWithPathDeps(
            'my_package',
            sdkConstraint: '>=3.0.0 <4.0.0',
            lib: [
              d.file('my_package.dart', '''
export 'sub/a.dart';
export 'sub/b.dart';
'''),
              d.dir('sub', [
                d.file('a.dart', '''
import 'shared.dart';
'''),
                d.file('b.dart', '''
import 'shared.dart';
import 'part_file.dart';
'''),
                d.file('shared.dart', '''
import 'stub.dart'
    if (dart.library.io) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
part 'part_file.dart';
'''),
                d.file('stub.dart', 'int stub() => 0;'),
                d.file('native.dart', "import 'dart:io';"),
                d.file('web.dart', "import 'dart:js_interop';"),
                d.file('part_file.dart', "part of 'shared.dart';"),
              ]),
            ],
          ),
        ]);
        await descriptor.create();

        final packageDir = p.normalize(
          p.join(descriptor.io.path, 'my_package'),
        );
        final realSession = AnalysisContextCollection(
          includedPaths: [packageDir],
        ).contextFor(packageDir).currentSession;
        final session = _CountingAnalysisSession(realSession);
        final cache = ParsedLibraryCache(session);

        final nativeGraph = LibraryGraph(
          session,
          Runtime.nativeAot.declaredVariables,
          parsedLibraryCache: cache,
        );
        final webGraph = LibraryGraph(
          session,
          Runtime.web.declaredVariables,
          parsedLibraryCache: cache,
        );
        final wasmGraph = LibraryGraph(
          session,
          Runtime.wasm.declaredVariables,
          disallowedConfigurationLibs: Runtime.wasm.disallowedConfigurationLibs,
          parsedLibraryCache: cache,
        );

        final sharedUri = Uri.parse('package:my_package/sub/shared.dart');
        expect(nativeGraph.directSuccessors(sharedUri), {
          Uri.parse('package:my_package/sub/native.dart'),
        });
        expect(webGraph.directSuccessors(sharedUri), {
          Uri.parse('package:my_package/sub/web.dart'),
        });
        expect(wasmGraph.directSuccessors(sharedUri), {
          Uri.parse('package:my_package/sub/web.dart'),
        });

        final partUri = Uri.parse('package:my_package/sub/part_file.dart');
        expect(nativeGraph.directSuccessors(partUri), isEmpty);
        expect(webGraph.directSuccessors(partUri), isEmpty);

        // Walk the full graph across all three runtime configurations.
        for (final graph in [nativeGraph, webGraph, wasmGraph]) {
          final finder = PathFinder<Uri>(graph, (_) => null);
          expect(
            finder
                .findPath(Uri.parse('package:my_package/my_package.dart'))
                .hasPath,
            false,
          );
          expect(
            finder.findPath(Uri.parse('package:my_package/sub/a.dart')).hasPath,
            false,
          );
          expect(
            finder.findPath(Uri.parse('package:my_package/sub/b.dart')).hasPath,
            false,
          );
        }

        expect(session.parseCounts, isNotEmpty);
        for (final entry in session.parseCounts.entries) {
          expect(
            entry.value,
            1,
            reason: '${entry.key} should only be parsed once',
          );
        }
      },
    );

    test(
      'caches language version, parse errors, and preserves URI errors',
      () async {
        final descriptor = d.dir('cache', [
          packageWithPathDeps(
            'my_package',
            sdkConstraint: '>=3.0.0 <4.0.0',
            lib: [
              d.file('opt_out.dart', '''
// @dart = 2.9
import 'dart:async';
'''),
              d.file('syntax_error.dart', 'import "dart:async"'),
              d.file('interpolated.dart', r"import 'foo_$bar.dart';"),
              d.file('conditional_interpolated.dart', r'''
import 'ok.dart'
    if (dart.library.io) 'bad_$x.dart';
'''),
              d.file('ok.dart', 'int ok() => 1;'),
            ],
          ),
        ]);
        await descriptor.create();

        final packageDir = p.normalize(
          p.join(descriptor.io.path, 'my_package'),
        );
        final realSession = AnalysisContextCollection(
          includedPaths: [packageDir],
        ).contextFor(packageDir).currentSession;
        final session = _CountingAnalysisSession(realSession);
        final cache = ParsedLibraryCache(session);

        final optOutPath = session.uriConverter.uriToPath(
          Uri.parse('package:my_package/opt_out.dart'),
        )!;
        final optOutLib = cache.parseFile(optOutPath);
        expect(optOutLib.languageVersion, Version(2, 9, 0));
        expect(optOutLib.directives, hasLength(1));
        expect(cache.parseFile(optOutPath), same(optOutLib));
        expect(session.parseCounts[optOutPath], 1);

        final errorPath = session.uriConverter.uriToPath(
          Uri.parse('package:my_package/syntax_error.dart'),
        )!;
        expect(cache.parseFile(errorPath), same(ParsedLibrary.empty));
        expect(cache.parseFile(errorPath), same(ParsedLibrary.empty));
        expect(session.parseCounts[errorPath], 1);

        final webGraph = LibraryGraph(
          session,
          Runtime.web.declaredVariables,
          parsedLibraryCache: cache,
        );
        final nativeGraph = LibraryGraph(
          session,
          Runtime.nativeAot.declaredVariables,
          parsedLibraryCache: cache,
        );

        // Interpolated URI in unconditional import still throws TagException.
        expect(
          () => webGraph.directSuccessors(
            Uri.parse('package:my_package/interpolated.dart'),
          ),
          throwsA(isA<TagException>()),
        );

        // Unselected conditional import with interpolated URI does not throw on web,
        // while selecting it on native throws TagException.
        expect(
          webGraph.directSuccessors(
            Uri.parse('package:my_package/conditional_interpolated.dart'),
          ),
          {Uri.parse('package:my_package/ok.dart')},
        );
        expect(
          () => nativeGraph.directSuccessors(
            Uri.parse('package:my_package/conditional_interpolated.dart'),
          ),
          throwsA(isA<TagException>()),
        );
      },
    );
  });
}
