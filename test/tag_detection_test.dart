// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:pana/src/tag_detection.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

class FakeLibraryGraph implements LibraryGraph {
  final Map<String, Set<String>> successors = {};
  FakeLibraryGraph();
  @override
  Set<Uri> directSuccessors(Uri uri) {
    return successors[uri.toString()].map(Uri.parse).toSet();
  }
}

/// Convenience for creating a descriptor of a package.
d.DirectoryDescriptor package(String name,
    {String sdkConstraint,
    List<String> dependencies = const [],
    List<d.Descriptor> lib = const [],
    Map pubspecExtras = const {},
    List<d.Descriptor> extraFiles = const []}) {
  final pubspec = json.encode(
    {
      'name': name,
      if (sdkConstraint != null) 'environment': {'sdk': sdkConstraint},
      'dependencies': {
        for (final dep in dependencies) dep: {'path': '../$dep'}
      },
      ...pubspecExtras,
    },
  );
  final packages = [
        '$name:lib/',
        for (final dep in dependencies) '$dep:../$dep/lib/'
      ].join('\n') +
      '\n';
  return d.dir(name, [
    d.file('.packages', packages),
    d.file('pubspec.yaml', pubspec),
    d.dir('lib', lib),
    ...extraFiles,
  ]);
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
          RuntimeViolationFinder(graph, Runtime.nativeAot)
              .findRuntimeViolation(Uri.parse('native_main.dart'))
              .hasPath,
          false);
    });
    test('fails with counter-example', () {
      expect(
          RuntimeViolationFinder(graph, Runtime.web)
              .findRuntimeViolation(Uri.parse('native_main.dart')),
          PathResult<Uri>.path([
            'native_main.dart',
            'native_helper.dart',
            'dart:io'
          ].map(Uri.parse).toList()));
    });
    test('handles cycles', () {
      expect(
          RuntimeViolationFinder(graph, Runtime.web)
              .findRuntimeViolation(Uri.parse('cyclic_main.dart')),
          PathResult<Uri>.noPath());
      expect(
          RuntimeViolationFinder(graph, Runtime.nativeAot)
              .findRuntimeViolation(Uri.parse('cyclic_main.dart')),
          PathResult<Uri>.path([
            'cyclic_main.dart',
            'cyclic1.dart',
            'cyclic2.dart',
            'web_helper.dart',
            'dart:html',
          ].map(Uri.parse).toList()));
    });
  });

  group('end2end tests', () {
    test('minimal', () async {
      final decriptor = d.dir('cache', [
        package('my_package',
            lib: [d.file('my_package.dart', 'int fourtyTwo() => 42;')])
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:dart', 'sdk:flutter'});
      expect(tagger.flutterPlatformTags(), {
        'platform:ios',
        'platform:android',
        'platform:web',
        'platform:linux',
        'platform:windows',
        'platform:macos'
      });
      expect(tagger.runtimeTags(), {
        'runtime:native-jit',
        'runtime:native-aot',
        'runtime:web',
      });
    });
    test('analyzes the primary libray', () async {
      final decriptor = d.dir('cache', [
        package('my_package', lib: [
          d.file('a.dart', '''
import 'dart:io';
int fourtyTwo() => 42;
'''),
          d.file('my_package.dart', '''
import 'dart:html';
int fourtyThree() => 43;
'''),
          d.file('z.dart', '''
import 'dart:io';
int fourtyTwo() => 42;
'''),
        ]),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:dart', 'sdk:flutter'});
      expect(tagger.flutterPlatformTags(), {
        'platform:web',
      });
      expect(tagger.runtimeTags(), {
        'runtime:web',
      });
    });
    test('no library named after package', () async {
      final decriptor = d.dir('cache', [
        package('my_package', lib: [
          d.file('other.dart', '''
import 'dart:mirrors';
int fourtyTwo() => 42;
'''),
        ])
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:dart'});
      expect(tagger.flutterPlatformTags(), isEmpty);
      expect(tagger.runtimeTags(), {'runtime:native-jit'});
    });

    test('using dart:mirrors disqualifies Flutter and aot', () async {
      final descriptor = d.dir('cache', [
        package('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:mirrors';
int fourtyTwo() => 42;
'''),
        ])
      ]);
      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:dart'});
      expect(tagger.flutterPlatformTags(), isEmpty);
      expect(tagger.runtimeTags(), {
        'runtime:native-jit',
      });
    });
    test('using flutter plugin', () async {
      final decriptor = d.dir('cache', [
        package('my_package', dependencies: [
          'my_dependency'
        ], lib: [
          d.file('my_package.dart', '''
import "package:my_dependency/my_dependency.dart";
import "dart:io";
int fourtyTwo() => fourtyThree() - 1;
''')
        ]),
        package('my_dependency', lib: [
          d.file('my_dependency.dart', 'int fourtyThree() => 43;')
        ], pubspecExtras: {
          'environment': {'flutter': '>=1.2.0<=2.0.0'},
          'flutter': {
            'plugin': {
              'platforms': {'web': {}, 'ios': {}}
            }
          }
        }),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:flutter'});
      expect(tagger.flutterPlatformTags(), {'platform:ios'});
      expect(tagger.runtimeTags(), isEmpty);
    });
    test('using flutter plugin2', () async {
      final decriptor = d.dir('cache', [
        package('my_package', dependencies: [
          'my_dependency'
        ], lib: [
          d.file('my_package.dart', '''
import "package:my_dependency/my_dependency.dart";
import "dart:html";
int fourtyTwo() => fourtyThree() - 1;
''')
        ]),
        package('my_dependency', lib: [
          d.file('my_dependency.dart', 'int fourtyThree() => 43;')
        ], pubspecExtras: {
          'environment': {'flutter': '>=1.2.0<=2.0.0'},
          'flutter': {
            'plugin': {
              'platforms': {'web': {}, 'ios': {}}
            }
          }
        }),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:flutter'});
      expect(tagger.flutterPlatformTags(), {'platform:web'});
      expect(tagger.runtimeTags(), isEmpty);
    });
    test('Using mirrors', () async {
      final decriptor = d.dir('cache', [
        package(
          'my_package',
          lib: [
            d.file('my_package.dart', '''
import "package:my_dependency/my_dependency.dart";
import "dart:io";
int fourtyTwo() => fourtyThree() - 1;
''')
          ],
          dependencies: ['my_dependency'],
        ),
        package('my_dependency', lib: [
          d.file('my_dependency.dart', '''
import 'dart:mirrors';
int fourtyThree() => 43;
'''),
          d.file('my_dependency_web.dart', '''
import 'dart:js';
int fourtyThree() => 43;
'''),
        ]),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:dart'});
      expect(tagger.flutterPlatformTags(), isEmpty);
      expect(tagger.runtimeTags(), {'runtime:native-jit'});
    });

    test('Configurable import', () async {
      final decriptor = d.dir('cache', [
        package(
          'my_package',
          lib: [
            d.file('my_package.dart', '''
import "package:my_dependency/my_dependency.dart" if (dart.library.js) "package:my_dependency/my_dependency_web.dart";;
int fourtyTwo() => fourtyThree() - 1;
''')
          ],
          dependencies: ['my_dependency'],
        ),
        package('my_dependency', lib: [
          d.file('my_dependency.dart', '''
import 'dart:io';
int fourtyThree() => 43;
'''),
          d.file('my_dependency_web.dart', '''
import 'dart:js';
int fourtyThree() => 43;
'''),
        ]),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:dart', 'sdk:flutter'});
      expect(tagger.flutterPlatformTags(), {
        'platform:android',
        'platform:ios',
        'platform:windows',
        'platform:linux',
        'platform:macos',
        'platform:web'
      });
      expect(tagger.runtimeTags(),
          {'runtime:native-aot', 'runtime:native-jit', 'runtime:web'});
    });

    test('file: imports are ignored', () async {
      final decriptor = d.dir('cache', [
        d.dir('my_package', [
          d.dir('lib', [
            d.file('my_package.dart', '''
import 'file:/abc/def.dart';
int fourtyTwo() => 42;
'''),
          ]),
          d.file('.packages', '''
my_package:lib/
'''),
          d.file(
            'pubspec.yaml',
            '''
name: my_package
''',
          )
        ])
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.sdkTags(), {'sdk:dart', 'sdk:flutter'});
      expect(tagger.flutterPlatformTags(), {
        'platform:ios',
        'platform:android',
        'platform:web',
        'platform:linux',
        'platform:windows',
        'platform:macos'
      });
      expect(tagger.runtimeTags(), {
        'runtime:native-jit',
        'runtime:native-aot',
        'runtime:web',
      });
    });
  });

  group('null-safe', () {
    test('compliant package depending on compliant package gets the tag',
        () async {
      final decriptor = d.dir('cache', [
        package('my_package',
            dependencies: ['my_dependency'],
            sdkConstraint: '>=2.10.0 <3.0.0',
            lib: [
              d.file('my_package.dart', 'int fourtyTwo() => 42;'),
            ]),
        package('my_dependency', sdkConstraint: '>=2.11.0 <3.0.0', lib: [
          d.file(
            'my_dependency.dart',
            "import 'dart:io'; int fourtyThree() => 43;",
          ),
        ]),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.nullSafetyTags(), ['is:null-safe']);
    });
    test('opting a library out (even one not reacahble from primary) fails',
        () async {
      final decriptor = d.dir('cache', [
        package('my_package', sdkConstraint: '>=2.11.0 <3.0.0', lib: [
          d.file('my_package.dart', 'int fourtyTwo() => 42;'),
          d.dir('src', [
            d.file(
              'stray_file.dart',
              '''
// @dart = 2.3
''',
            ),
          ]),
        ])
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.nullSafetyTags(), []);
    });

    test('opting a library to older version still allowing null-safety is ok',
        () async {
      final decriptor = d.dir('cache', [
        package('my_package', sdkConstraint: '>=2.11.0 <3.0.0', lib: [
          d.file('my_package.dart', 'int fourtyTwo() => 42;'),
          d.dir('src', [
            d.file('stray_file.dart', '// @dart = 2.10\n'),
          ]),
        ])
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.nullSafetyTags(), ['is:null-safe']);
    });

    test('depending on a not-null-safe package gets fails', () async {
      final decriptor = d.dir('cache', [
        package('my_package',
            dependencies: ['my_dependency'],
            sdkConstraint: '>=2.10.0 <3.0.0',
            lib: [
              d.file('my_package.dart', 'int fourtyTwo() => 42;'),
            ]),
        package('my_dependency', sdkConstraint: '>=2.9.0 <3.0.0', lib: [
          d.file(
            'my_dependency.dart',
            "import 'dart:io'; int fourtyThree() => 43;",
          ),
        ]),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.nullSafetyTags(), []);
    });

    test('An opt-out library in a dependency fails', () async {
      final decriptor = d.dir('cache', [
        package('my_package',
            dependencies: ['my_dependency'],
            sdkConstraint: '>=2.10.0 <3.0.0',
            lib: [
              d.file('my_package.dart', 'int fourtyTwo() => 42;'),
            ]),
        package('my_dependency', sdkConstraint: '>=2.10.0 <3.0.0', lib: [
          d.file(
            'my_dependency.dart',
            '// @dart = 2.9',
          ),
        ]),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.nullSafetyTags(), []);
    });

    test('An opt-out test still gets tag', () async {
      final decriptor = d.dir('cache', [
        package('my_package', sdkConstraint: '>=2.10.0 <3.0.0', lib: [
          d.file('my_package.dart', 'int fourtyTwo() => 42;'),
        ], extraFiles: [
          d.dir('test', [
            d.file('main_test.dart', '''
// @dart = 2.9
import 'package:my_package/my_package.dart';

void main() {
  if (!fourtyTwo() == 42) throw 'failed';
}
''')
          ])
        ]),
      ]);
      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expect(tagger.nullSafetyTags(), ['is:null-safe']);
    });
  });
}
