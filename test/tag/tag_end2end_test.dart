// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:pana/src/tag/tagger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../package_descriptor.dart';

void _expectTagging(void Function(List<String>, List<Explanation>) f,
    {Object? tags = anything, Object? explanations = anything}) {
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
      _expectTagging(tagger.platformTags,
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
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
    });
    test('analyzes the primary library', () async {
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
      _expectTagging(tagger.platformTags, tags: {
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
      _expectTagging(
        tagger.platformTags,
        tags: {'platform:linux', 'platform:macos', 'platform:windows'},
      );
      _expectTagging(tagger.runtimeTags, tags: {'runtime:native-jit'});
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
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
      _expectTagging(tagger.platformTags,
          tags: {'platform:ios', 'platform:android'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
      _expectTagging(tagger.flutterPluginTags, tags: {'is:plugin'});
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
      _expectTagging(tagger.platformTags,
          tags: {'platform:ios', 'platform:android'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
      _expectTagging(tagger.flutterPluginTags, tags: {'is:plugin'});
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
      _expectTagging(
        tagger.platformTags,
        tags: {'platform:linux', 'platform:macos', 'platform:windows'},
      );
      _expectTagging(tagger.runtimeTags, tags: {
        'runtime:native-jit',
      });
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
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
              'platforms': {
                'web': <String, String>{},
                'ios': <String, String>{}
              }
            }
          }
        }),
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.platformTags, tags: {'platform:ios'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
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
              'platforms': {
                'web': <String, String>{},
                'ios': <String, String>{},
              }
            }
          }
        }),
      ]);
      await descriptor.create();
      final tagger = Tagger(p.join(descriptor.io.path, 'my_package'));
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.platformTags, tags: {'platform:web'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
    });
    test('Flutter plugins declarations are respected', () async {
      final descriptor = d.dir('cache', [
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
              'platforms': {
                'web': <String, String>{},
                'ios': <String, String>{},
              }
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
              'platforms': {
                'web': <String, String>{},
                'linux': <String, String>{},
              }
            }
          }
        })
      ]);

      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.platformTags,
          tags: {'platform:ios', 'platform:web'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
      _expectTagging(tagger.flutterPluginTags, tags: {'is:plugin'});
    });

    test('Declaring top-level platforms', () async {
      final descriptor = d.dir(
        'cache',
        [
          packageWithPathDeps(
            'my_package',
            pubspecExtras: {
              'platforms': {
                'windows': null,
                'android': null,
              },
            },
          ),
        ],
      );
      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter', 'sdk:dart'});
      _expectTagging(tagger.platformTags,
          tags: {'platform:windows', 'platform:android'});
      _expectTagging(tagger.runtimeTags, tags: [
        'runtime:native-aot',
        'runtime:native-jit',
        'runtime:web',
      ]);
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
    });

    test('Top-level platforms in dependency', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:io';
import 'package:my_package_linux/my_package_linux.dart';
int fourtyTwo() => 42;
'''),
        ], dependencies: [
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
          'platforms': {
            'linux': null,
          }
        })
      ]);

      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.platformTags, tags: {'platform:linux'});
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
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
                'Package is not compatible with the Flutter SDK. Because:')),
      ]);
      _expectTagging(tagger.platformTags,
          tags: {'platform:linux', 'platform:macos', 'platform:windows'},
          explanations: contains(
            _explanation(
                finding: 'Package not compatible with platform Android'),
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
* `dart:io`'''),
      });
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
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
      _expectTagging(tagger.platformTags,
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
          tags: {
            'runtime:native-aot',
            'runtime:native-jit',
            'runtime:web',
          },
          explanations: isEmpty);
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
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
          d.dir('.dart_tool', [
            d.file(
              'package_config.json',
              json.encode({
                'configVersion': 2,
                'packages': [
                  {
                    'name': 'my_package',
                    'rootUri': '..',
                    'packageUri': 'lib/',
                    'languageVersion': '2.12',
                  },
                ],
              }),
            ),
          ]),
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
      _expectTagging(tagger.platformTags,
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
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
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
      _expectTagging(tagger.platformTags,
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
      _expectTagging(tagger.flutterPluginTags, tags: isEmpty);
    });
    test('no dart files with Flutter plugins declarations', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps(
          'my_package',
          lib: [d.file('asset.json', '{"status": "ok"}')],
          pubspecExtras: {
            'environment': {'flutter': '>=1.2.0<=2.0.0'},
            'flutter': {
              'plugin': {
                'platforms': {
                  'web': <String, String>{},
                  'ios': <String, String>{},
                }
              }
            }
          },
        ),
      ]);

      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      _expectTagging(tagger.sdkTags, tags: {'sdk:flutter'});
      _expectTagging(tagger.platformTags, tags: {
        'platform:ios',
        'platform:web',
      });
      _expectTagging(tagger.runtimeTags, tags: isEmpty);
      _expectTagging(tagger.flutterPluginTags, tags: {'is:plugin'});
    });
  });

  group('wasm tag', () {
    test('Excluded with dart:js', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:js';
'''),
        ])
      ]);

      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      _expectTagging(tagger.wasmReadyTag,
          tags: isNot(contains('is:wasm-ready')));
    });

    test('Excluded with dart:js_util', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:js_util';
'''),
        ])
      ]);

      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      _expectTagging(tagger.wasmReadyTag,
          tags: isNot(contains('is:wasm-ready')));
    });
    test('Excluded with dart:html', () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:html';
'''),
        ])
      ]);

      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      _expectTagging(tagger.wasmReadyTag,
          tags: isNot(contains('is:wasm-ready')));
    });

    test(
        'Included with dart:ui, dart:ui_web dart:js_interop dart:js_interop_unsafe',
        () async {
      final descriptor = d.dir('cache', [
        packageWithPathDeps('my_package', lib: [
          d.file('my_package.dart', '''
import 'dart:ui';
import 'dart:ui_web';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
'''),
        ])
      ]);

      await descriptor.create();
      final tagger = Tagger('${descriptor.io.path}/my_package');
      _expectTagging(tagger.wasmReadyTag, tags: contains('is:wasm-ready'));
    });
  });
}

Matcher _explanation(
    {Object? finding = anything, Object? explanation = anything}) {
  return allOf(
    HasFinding(finding),
    _HasDescription(explanation),
  );
}

class _HasDescription extends CustomMatcher {
  _HasDescription(Object? matcher)
      : super('Explanation with a', 'explanation', matcher);

  @override
  String? featureValueOf(Object? actual) => (actual as Explanation).explanation;
}

class HasFinding extends CustomMatcher {
  HasFinding(Object? matcher) : super('Explanation with a', 'finding', matcher);

  @override
  String featureValueOf(Object? actual) => (actual as Explanation).finding;
}
