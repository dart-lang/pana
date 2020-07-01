// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/tag_detection.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package_descriptor.dart';

class FakeLibraryGraph implements LibraryGraph {
  final Map<String, Set<String>> successors = {};
  FakeLibraryGraph();
  @override
  Set<Uri> directSuccessors(Uri uri) {
    return successors[uri.toString()].map(Uri.parse).toSet();
  }
}

void expectTagging(void Function(List<String>, List<Explanation>) f,
    {dynamic tags = anything, dynamic explanations = anything}) {
  final actualTags = <String>[];
  final actualExplanations = <Explanation>[];
  f(actualTags, actualExplanations);
  expect(actualTags, tags);
  if (explanations != null) {
    expect(actualExplanations, explanations);
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

  group('end2end tests', () {
    test('minimal', () async {
      final descriptor = d.dir('cache', [
        package('my_package',
            lib: [d.file('my_package.dart', 'int fourtyTwo() => 42;')])
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.sdkTags,
          tags: {'sdk:dart', 'sdk:flutter'}, explanations: isEmpty);
      expectTagging(tagger.flutterPlatformTags,
          tags: {
            'platform:ios',
            'platform:android',
            'platform:web',
            'platform:linux',
            'platform:windows',
            'platform:macos'
          },
          explanations: isEmpty);
      expectTagging(tagger.runtimeTags,
          tags: {
            'runtime:native-jit',
            'runtime:native-aot',
            'runtime:web',
          },
          explanations: isEmpty);
    });
    test('analyzes the primary libray', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.sdkTags, tags: {'sdk:dart', 'sdk:flutter'});
      expectTagging(tagger.flutterPlatformTags, tags: {
        'platform:web',
      });
      expectTagging(tagger.runtimeTags, tags: {
        'runtime:web',
      });
    });
    test('no library named after package', () async {
      final descriptor = d.dir('cache', [
        package('my_package', lib: [
          d.file('other.dart', '''
import 'dart:mirrors';
int fourtyTwo() => 42;
'''),
        ])
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.sdkTags, tags: {'sdk:dart'});
      expectTagging(tagger.flutterPlatformTags, tags: isEmpty);
      expectTagging(tagger.runtimeTags, tags: {'runtime:native-jit'});
    });

    test('flutter old style plugins', () async {
      final descriptor = d.dir('cache', [
        package('my_package', lib: [
          d.file('a.dart', '''
import 'dart:io';
int fourtyTwo() => 42;
'''),
        ], pubspecExtras: {
          'environment': {'flutter': '>=1.2.0<=2.0.0'},
          'flutter': {
            'plugin': {
              'iosPrefix': 'my_package',
              'androidPackage': 'my,.android.package',
            }
          }
        }),
      ]);

      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      expectTagging(tagger.flutterPlatformTags,
          tags: {'platform:ios', 'platform:android'});
      expectTagging(tagger.runtimeTags, tags: isEmpty);
    });

    test('flutter old style plugins2', () async {
      final descriptor = d.dir('cache', [
        package('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:io';
int fourtyTwo() => 42;
'''),
        ], pubspecExtras: {
          'environment': {'flutter': '>=1.2.0<=2.0.0'},
          'flutter': {
            'plugin': {
              'iosPrefix': 'my_package',
            }
          }
        })
      ]);

      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      expectTagging(tagger.flutterPlatformTags,
          tags: {'platform:ios', 'platform:android'});
      expectTagging(tagger.runtimeTags, tags: isEmpty);
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
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.sdkTags, tags: {'sdk:dart'});
      expectTagging(tagger.flutterPlatformTags, tags: isEmpty);
      expectTagging(tagger.runtimeTags, tags: {
        'runtime:native-jit',
      });
    });
    test('using flutter plugin', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      expectTagging(tagger.flutterPlatformTags, tags: {'platform:ios'});
      expectTagging(tagger.runtimeTags, tags: isEmpty);
    });
    test('using flutter plugin2', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      expectTagging(tagger.flutterPlatformTags, tags: {'platform:web'});
      expectTagging(tagger.runtimeTags, tags: isEmpty);
    });
    test('Flutter plugins declarations are respected', () async {
      final decriptor = d.dir('cache', [
        package('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:io';
import 'package:my_package_linux/my_package_linux.dart';
int fourtyTwo() => 42;
'''),
        ], pubspecExtras: {
          'environment': {'flutter': '>=1.2.0<=2.0.0'},
          'flutter': {
            'plugin': {
              'platforms': {'web': {}, 'ios': {}}
            }
          }
        }, dependencies: [
          'my_package_linux'
        ], extraFiles: [
          d.file('.packages', '''
my_package:lib/
my_package_linux:../my_package_linux/lib/
'''),
        ]),
        package('my_package_linux', lib: [
          d.file('my_package_linux.dart', '''
import 'dart:io';
int fourtyTwo() => 42;
'''),
        ], pubspecExtras: {
          'environment': {'flutter': '>=1.2.0<=2.0.0'},
          'flutter': {
            'plugin': {
              'platforms': {'web': {}, 'linux': {}}
            }
          }
        })
      ]);

      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      expectTagging(tagger.flutterPlatformTags,
          tags: {'platform:ios', 'platform:web'});
      expectTagging(tagger.runtimeTags, tags: isEmpty);
    });

    test('Using mirrors', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      expectTagging(tagger.sdkTags, tags: {
        'sdk:dart'
      }, explanations: [
        explanation(
            finding: 'Package not compatible with SDK flutter',
            explanation:
                'Because it is not compatible with any of the supported '
                'runtimes: flutter-native, flutter-web')
      ]);
      expectTagging(tagger.flutterPlatformTags,
          tags: isEmpty,
          explanations: contains(
            explanation(
                finding:
                    'Package not compatible with runtime flutter-native on android'),
          ));
      expectTagging(tagger.runtimeTags, tags: {
        'runtime:native-jit'
      }, explanations: {
        explanation(
            finding: 'Package not compatible with runtime native-aot',
            explanation:
                'Because of the import of dart:mirrors via the import chain '
                '`package:my_package/my_package.dart` → `package:my_dependency/my_dependency.dart` → `dart:mirrors`'),
        explanation(
            finding: 'Package not compatible with runtime web',
            explanation:
                'Because of the import of dart:io via the import chain '
                '`package:my_package/my_package.dart` → `dart:io`')
      });
    });

    test('Configurable import', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      expectTagging(tagger.sdkTags,
          tags: {'sdk:dart', 'sdk:flutter'}, explanations: isEmpty);
      expectTagging(tagger.flutterPlatformTags,
          tags: {
            'platform:android',
            'platform:ios',
            'platform:windows',
            'platform:linux',
            'platform:macos',
            'platform:web'
          },
          explanations: isEmpty);
      expectTagging(tagger.runtimeTags,
          tags: {'runtime:native-aot', 'runtime:native-jit', 'runtime:web'},
          explanations: isEmpty);
    });

    test('file: imports are ignored', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      expectTagging(tagger.sdkTags,
          tags: {'sdk:dart', 'sdk:flutter'}, explanations: isEmpty);
      expectTagging(tagger.flutterPlatformTags,
          tags: {
            'platform:ios',
            'platform:android',
            'platform:web',
            'platform:linux',
            'platform:windows',
            'platform:macos'
          },
          explanations: isEmpty);

      expectTagging(tagger.runtimeTags,
          tags: {
            'runtime:native-jit',
            'runtime:native-aot',
            'runtime:web',
          },
          explanations: isEmpty);
    });
  });

  group('null-safe', () {
    test('compliant package depending on compliant package gets the tag',
        () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.nullSafetyTags,
          tags: ['is:null-safe'], explanations: isEmpty);
    });
    test('opting a library out (even one not reachahble from primary) fails',
        () async {
      final descriptor = d.dir('cache', [
        package('my_package', sdkConstraint: '>=2.11.0 <3.0.0', lib: [
          d.file('my_package.dart', 'int fourtyTwo() => 42;'),
          d.dir('src', [
            d.file(
              'stray_file.dart',
              '''
// @dart = 2.3''',
            ),
          ]),
        ])
      ]);

      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      expectTagging(tagger.nullSafetyTags, tags: isEmpty, explanations: [
        explanation(
            finding: 'Package is not null safe',
            explanation:
                'Because src/stray_file.dart is opting out in package package:my_package'),
      ]);
    });

    test('opting a library to older version still allowing null-safety is ok',
        () async {
      final descriptor = d.dir('cache', [
        package('my_package', sdkConstraint: '>=2.11.0 <3.0.0', lib: [
          d.file('my_package.dart', 'int fourtyTwo() => 42;'),
          d.dir('src', [
            d.file('stray_file.dart', '// @dart = 2.10\n'),
          ]),
        ])
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.nullSafetyTags,
          tags: ['is:null-safe'], explanations: isEmpty);
    });

    test('depending on a not-null-safe package gets fails', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      expectTagging(tagger.nullSafetyTags, tags: isEmpty, explanations: [
        explanation(
          finding: 'Package is not null safe',
          explanation: allOf(
              contains(
                  'Because of the language version from the sdk constraint in pubspec.yaml'),
              contains(
                  'package:my_dependency via dependency path: package:my_package->package:my_dependency')),
        )
      ]);
    });

    test('An opt-out library in a dependency fails', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      expectTagging(tagger.nullSafetyTags, tags: isEmpty, explanations: [
        explanation(
            finding: 'Package is not null safe',
            explanation:
                contains('Because my_dependency.dart is opting out in package '
                    'package:my_dependency via dependency path: '
                    'package:my_package->package:my_dependency'))
      ]);
    });

    test('An opt-out test still gets tag', () async {
      final descriptor = d.dir('cache', [
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
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      expectTagging(tagger.nullSafetyTags,
          tags: ['is:null-safe'], explanations: isEmpty);
    });

    test('Broken imports gets reported', () async {
      final descriptor = d.dir('cache', [
        package('my_package', sdkConstraint: '>=2.10.0 <3.0.0', lib: [
          d.file('my_package.dart', 'import "package:missing/missing.dart";'),
        ], dependencies: [
          'missing'
        ]),
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      final tagDetectionFailed = contains(
        explanation(
          finding: 'Tag detection failed.',
        ),
      );

      expectTagging(
        tagger.nullSafetyTags,
        explanations: tagDetectionFailed,
      );
      expectTagging(
        tagger.flutterPlatformTags,
        explanations: tagDetectionFailed,
      );
      expectTagging(
        tagger.sdkTags,
        explanations: tagDetectionFailed,
      );
      expectTagging(
        tagger.runtimeTags,
        explanations: tagDetectionFailed,
      );
    });
  });
}

Matcher explanation({finding = anything, explanation = anything}) {
  return allOf(
    HasFinding(finding),
    HasDescription(explanation),
  );
}

class HasDescription extends CustomMatcher {
  HasDescription(matcher) : super('Explanation with a', 'explanation', matcher);

  @override
  String featureValueOf(actual) => (actual as Explanation).explanation;
}

class HasFinding extends CustomMatcher {
  HasFinding(matcher) : super('Explanation with a', 'finding', matcher);

  @override
  String featureValueOf(actual) => (actual as Explanation).finding;
}
