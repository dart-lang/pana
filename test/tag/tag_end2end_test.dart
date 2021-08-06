// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:pana/src/tag/tagger.dart';

import '../package_descriptor.dart';

void _expectTagging(void Function(List<String>, List<Explanation>) f,
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
  group('end2end tests', () {
    test('minimal', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package',
            lib: [d.file('my_package.dart', 'int fourtyTwo() => 42;')])
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      _expectTagging(tagger.sdkTags,
          tags: {'sdk:dart', 'sdk:flutter'}, explanations: isEmpty);
      _expectTagging(tagger.flutterPlatformTags,
          tags: {
            'platform:ios',
            'platform:android',
            'platform:web',
            'platform:linux',
            'platform:windows',
            'platform:macos'
          },
          explanations: isEmpty);
      _expectTagging(tagger.runtimeTags,
          tags: {
            'runtime:native-jit',
            'runtime:native-aot',
            'runtime:web',
          },
          explanations: isEmpty);
    });
    test('analyzes the primary libray', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
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
      _expectTagging(tagger.sdkTags, tags: {'sdk:dart', 'sdk:flutter'});
      _expectTagging(tagger.flutterPlatformTags, tags: {
        'platform:web',
      });
      _expectTagging(tagger.runtimeTags, tags: {
        'runtime:web',
      });
    });
    test('no library named after package', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
          d.file('other.dart', '''
import 'dart:mirrors';
int fourtyTwo() => 42;
'''),
        ])
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      _expectTagging(tagger.sdkTags, tags: {'sdk:dart'});
      _expectTagging(tagger.flutterPlatformTags, tags: isEmpty);
      _expectTagging(tagger.runtimeTags, tags: {'runtime:native-jit'});
    });

    test('flutter old style plugins', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
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
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.flutterPlatformTags,
          tags: {'platform:ios', 'platform:android'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
    });

    test('flutter old style plugins2', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
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
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.flutterPlatformTags,
          tags: {'platform:ios', 'platform:android'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
    });

    test('using dart:mirrors disqualifies Flutter and aot', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:mirrors';
int fourtyTwo() => 42;
'''),
        ])
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      _expectTagging(tagger.sdkTags, tags: {'sdk:dart'});
      _expectTagging(tagger.flutterPlatformTags, tags: isEmpty);
      _expectTagging(tagger.runtimeTags, tags: {
        'runtime:native-jit',
      });
    });
    test('using flutter plugin', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', dependencies: [
          'my_dependency'
        ], lib: [
          d.file('my_package.dart', '''
import "package:my_dependency/my_dependency.dart";
import "dart:io";
int fourtyTwo() => fourtyThree() - 1;
''')
        ]),
        packageWithPathDeps('my_dependency', lib: [
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
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.flutterPlatformTags, tags: {'platform:ios'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
    });
    test('using flutter plugin2', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', dependencies: [
          'my_dependency'
        ], lib: [
          d.file('my_package.dart', '''
import "package:my_dependency/my_dependency.dart";
import "dart:html";
int fourtyTwo() => fourtyThree() - 1;
''')
        ]),
        packageWithPathDeps('my_dependency', lib: [
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
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.flutterPlatformTags, tags: {'platform:web'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
    });
    test('Flutter plugins declarations are respected', () async {
      final decriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
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
        packageWithPathDeps('my_package_linux', lib: [
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
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.flutterPlatformTags,
          tags: {'platform:ios', 'platform:web'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
    });

    test('Using mirrors', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps(
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
        packageWithPathDeps('my_dependency', lib: [
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
      _expectTagging(tagger.sdkTags, tags: {
        'sdk:dart'
      }, explanations: [
        _explanation(
            finding: 'Package is not compatible with the Flutter SDK.',
            explanation: startsWith(
                'Because it is not compatible with any of the supported '
                'runtimes: `flutter-native`, `flutter-web`.\n\n'
                'Package is not compatible with Flutter SDK using runtime `flutter-native`. Because:')),
      ]);
      _expectTagging(tagger.flutterPlatformTags,
          tags: isEmpty,
          explanations: contains(
            _explanation(
                finding:
                    'Package not compatible with runtime flutter-native on Android'),
          ));
      _expectTagging(tagger.runtimeTags, tags: {
        'runtime:native-jit'
      }, explanations: {
        _explanation(
            finding: 'Package not compatible with runtime native-aot',
            explanation: '''
Because:
* `package:my_package/my_package.dart` that imports:
* `package:my_dependency/my_dependency.dart` that imports:
* `dart:mirrors`'''),
        _explanation(
            finding: 'Package not compatible with runtime js', explanation: '''
Because:
* `package:my_package/my_package.dart` that imports:
* `dart:io`''')
      });
    });

    test('Configurable import', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps(
          'my_package',
          lib: [
            d.file('my_package.dart', '''
import "package:my_dependency/my_dependency.dart" if (dart.library.js) "package:my_dependency/my_dependency_web.dart";;
int fourtyTwo() => fourtyThree() - 1;
''')
          ],
          dependencies: ['my_dependency'],
        ),
        packageWithPathDeps('my_dependency', lib: [
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
      _expectTagging(tagger.sdkTags,
          tags: {'sdk:dart', 'sdk:flutter'}, explanations: isEmpty);
      _expectTagging(tagger.flutterPlatformTags,
          tags: {
            'platform:android',
            'platform:ios',
            'platform:windows',
            'platform:linux',
            'platform:macos',
            'platform:web'
          },
          explanations: isEmpty);
      _expectTagging(tagger.runtimeTags,
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
      _expectTagging(tagger.sdkTags,
          tags: {'sdk:dart', 'sdk:flutter'}, explanations: isEmpty);
      _expectTagging(tagger.flutterPlatformTags,
          tags: {
            'platform:ios',
            'platform:android',
            'platform:web',
            'platform:linux',
            'platform:windows',
            'platform:macos'
          },
          explanations: isEmpty);

      _expectTagging(tagger.runtimeTags,
          tags: {
            'runtime:native-jit',
            'runtime:native-aot',
            'runtime:web',
          },
          explanations: isEmpty);
    });

    test('no dart files', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package',
            lib: [d.file('asset.json', '{"status": "ok"}')])
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      _expectTagging(tagger.sdkTags,
          tags: {'sdk:dart', 'sdk:flutter'}, explanations: isEmpty);
      _expectTagging(tagger.flutterPlatformTags,
          tags: {
            'platform:ios',
            'platform:android',
            'platform:web',
            'platform:linux',
            'platform:windows',
            'platform:macos'
          },
          explanations: isEmpty);
      _expectTagging(tagger.runtimeTags,
          tags: {
            'runtime:native-jit',
            'runtime:native-aot',
            'runtime:web',
          },
          explanations: isEmpty);
    });
    test('no dart files with Flutter plugins declarations', () async {
      final decriptor = d.dir('cache', [
        packageWithPathDeps(
          'my_package',
          lib: [d.file('asset.json', '{"status": "ok"}')],
          pubspecExtras: {
            'environment': {'flutter': '>=1.2.0<=2.0.0'},
            'flutter': {
              'plugin': {
                'platforms': {'web': {}, 'ios': {}}
              }
            }
          },
        ),
      ]);

      await decriptor.create();
      final tagger = Tagger('${decriptor.io.path}/my_package');
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.flutterPlatformTags, tags: {
        'platform:ios',
        'platform:android',
        'platform:web',
        'platform:linux',
        'platform:windows',
        'platform:macos',
      });
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
    });
  });
}

Matcher _explanation({finding = anything, explanation = anything}) {
  return allOf(
    HasFinding(finding),
    _HasDescription(explanation),
  );
}

class _HasDescription extends CustomMatcher {
  _HasDescription(matcher)
      : super('Explanation with a', 'explanation', matcher);

  @override
  String? featureValueOf(actual) => (actual as Explanation).explanation;
}

class HasFinding extends CustomMatcher {
  HasFinding(matcher) : super('Explanation with a', 'finding', matcher);

  @override
  String featureValueOf(actual) => (actual as Explanation).finding;
}
