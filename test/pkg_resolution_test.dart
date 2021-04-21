// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:pana/src/pkg_resolution.dart';
import 'package:pana/src/pubspec.dart';

void main() {
  group('pana #469', () {
    final pubspec = Pubspec.parseYaml('''name: x
version: 0.0.1
environment:
  sdk: ">=2.0.0-dev.68.0 <3.0.0"

dependencies:
  build: ^1.0.2
  source_gen: ^0.9.3
  code_builder: ^3.1.3
  pref_gen_annotations: ^0.0.1

dev_dependencies:
  build_runner: ^1.1.2
''');

    test('parse clean upgrade', () {
      final output = '''MSG : Resolving dependencies...
MSG :   analyzer 0.34.1
    |   args 1.5.1
    |   async 2.0.8
    |   build 1.0.2
    |   built_collection 4.1.0
    |   built_value 6.2.0
    |   charcode 1.1.2
    |   code_builder 3.1.3
    |   collection 1.14.11
    |   convert 2.1.1
    |   crypto 2.0.6
    |   csslib 0.14.6
    |   dart_style 1.2.2
    |   fixnum 0.10.9
    |   front_end 0.1.8
    |   glob 1.1.7
    |   html 0.13.3+3
    |   kernel 0.3.8
    |   logging 0.11.3+2
    |   matcher 0.12.4
    |   meta 1.1.6
    |   package_config 1.0.5
    |   path 1.6.2
    |   plugin 0.2.0+3
    |   pref_gen_annotations 0.0.2
    |   pub_semver 1.4.2
    |   quiver 2.0.1
    |   source_gen 0.9.3
    |   source_span 1.4.1
    |   stack_trace 1.9.3
    |   string_scanner 1.0.4
    |   typed_data 1.1.6
    |   utf 0.9.0+5
    |   watcher 0.9.7+10
    |   yaml 2.1.15
MSG : Downloading build 1.0.2...
MSG : Downloading source_gen 0.9.3...
MSG : Downloading code_builder 3.1.3...
MSG : Downloading pref_gen_annotations 0.0.2...
MSG : Downloading async 2.0.8...
MSG : Downloading source_span 1.4.1...
MSG : Downloading logging 0.11.3+2...
MSG : Downloading meta 1.1.6...
MSG : Downloading charcode 1.1.2...
MSG : Downloading glob 1.1.7...
MSG : Downloading built_value 6.2.0...
MSG : Downloading fixnum 0.10.9...
MSG : Downloading built_collection 4.1.0...
MSG : Downloading crypto 2.0.6...
MSG : Downloading typed_data 1.1.6...
MSG : Downloading convert 2.1.1...
MSG : Downloading analyzer 0.34.1...
MSG : Downloading pub_semver 1.4.2...
MSG : Downloading kernel 0.3.8...
MSG : Downloading front_end 0.1.8...
MSG : Downloading yaml 2.1.15...
MSG : Downloading plugin 0.2.0+3...
MSG : Downloading package_config 1.0.5...
MSG : Downloading string_scanner 1.0.4...
MSG : Downloading path 1.6.2...
MSG : Downloading watcher 0.9.7+10...
MSG : Downloading matcher 0.12.4...
MSG : Downloading collection 1.14.11...
MSG : Downloading html 0.13.3+3...
MSG : Downloading utf 0.9.0+5...
MSG : Downloading csslib 0.14.6...
MSG : Downloading args 1.5.1...
MSG : Downloading quiver 2.0.1...
MSG : Downloading stack_trace 1.9.3...
MSG : Downloading dart_style 1.2.2...
MSG : No dependencies changed.''';

      final pr = createPkgResolution(pubspec, output);
      expect(pr.dependencies, hasLength(36));
      expect(
          pr.dependencies
              .firstWhere((d) => d.package == 'analyzer')
              .resolved
              .toString(),
          '0.34.1');
    });

    test('parse version-changing upgrade', () {
      final output = '''MSG : Resolving dependencies...
MSG :   analyzer 0.34.1
    |   args 1.5.1
    |   async 2.0.8
    |   build 1.0.2
    |   built_collection 4.1.0
    |   built_value 6.2.0
    |   charcode 1.1.2
    |   code_builder 3.1.3
    |   collection 1.14.11
    |   convert 2.1.1
    |   crypto 2.0.6
    |   csslib 0.14.6
    |   dart_style 1.2.2
    |   fixnum 0.10.9
    |   front_end 0.1.8
    |   glob 1.1.7
    |   html 0.13.3+3
    |   kernel 0.3.8
    |   logging 0.11.3+2
    |   matcher 0.12.4
    |   meta 1.1.6
    |   package_config 1.0.5
    |   path 1.6.2
    |   plugin 0.2.0+3
    |   pref_gen_annotations 0.0.2
    |   pub_semver 1.4.2
    |   quiver 2.0.1
    |   source_gen 0.9.3
    |   source_span 1.4.1
    |   stack_trace 1.9.3
    |   string_scanner 1.0.4
    |   typed_data 1.1.6
    |   utf 0.9.0+5
    |   watcher 0.9.7+10
    |   yaml 2.1.15
    | These packages are no longer being depended on:
    | - build_config 0.3.1+4
    | - build_resolvers 0.2.2+7
    | - build_runner 1.1.2
    | - build_runner_core 1.1.2
    | - graphs 0.1.3+1
    | - http_multi_server 2.0.5
    | - http_parser 3.1.3
    | - io 0.3.3
    | - js 0.6.1+1
    | - json_annotation 2.0.0
    | - mime 0.9.6+2
    | - pedantic 1.4.0
    | - pool 1.3.6
    | - pubspec_parse 0.1.3
    | - shelf 0.7.4
    | - shelf_web_socket 0.2.2+4
    | - stream_channel 1.6.8
    | - stream_transform 0.0.14+1
    | - timing 0.1.1+1
    | - web_socket_channel 1.0.9
MSG : Downloading build 1.0.2...
MSG : Downloading source_gen 0.9.3...
MSG : Downloading code_builder 3.1.3...
MSG : Downloading pref_gen_annotations 0.0.2...
MSG : Downloading async 2.0.8...
MSG : Downloading source_span 1.4.1...
MSG : Downloading logging 0.11.3+2...
MSG : Downloading meta 1.1.6...
MSG : Downloading charcode 1.1.2...
MSG : Downloading glob 1.1.7...
MSG : Downloading built_value 6.2.0...
MSG : Downloading fixnum 0.10.9...
MSG : Downloading built_collection 4.1.0...
MSG : Downloading crypto 2.0.6...
MSG : Downloading typed_data 1.1.6...
MSG : Downloading convert 2.1.1...
MSG : Downloading analyzer 0.34.1...
MSG : Downloading pub_semver 1.4.2...
MSG : Downloading kernel 0.3.8...
MSG : Downloading front_end 0.1.8...
MSG : Downloading yaml 2.1.15...
MSG : Downloading plugin 0.2.0+3...
MSG : Downloading package_config 1.0.5...
MSG : Downloading string_scanner 1.0.4...
MSG : Downloading path 1.6.2...
MSG : Downloading watcher 0.9.7+10...
MSG : Downloading matcher 0.12.4...
MSG : Downloading collection 1.14.11...
MSG : Downloading html 0.13.3+3...
MSG : Downloading utf 0.9.0+5...
MSG : Downloading csslib 0.14.6...
MSG : Downloading args 1.5.1...
MSG : Downloading quiver 2.0.1...
MSG : Downloading stack_trace 1.9.3...
MSG : Downloading dart_style 1.2.2...
MSG : Changed 20 dependencies!''';

      final pr = createPkgResolution(pubspec, output);
      expect(pr.dependencies, hasLength(36));
      expect(
          pr.dependencies
              .firstWhere((d) => d.package == 'analyzer')
              .resolved
              .toString(),
          '0.34.1');
    });
  });

  test('replaced by <pkg>', () {
    final pubspec = Pubspec.parseYaml('''name: x
version: 0.0.1
environment:
  sdk: ">=2.0.0 <3.0.0"

dependencies:
  http_server: any
''');

    final pr = createPkgResolution(pubspec, '''
MSG : Resolving dependencies...
MSG :   http_server 1.0.0 (discontinued replaced by shelf)
    |   mime 1.0.0
    |   path 1.8.0
MSG : No dependencies changed.
''');
    expect(pr.dependencies.map((d) => d.package).toSet(),
        {'http_server', 'mime', 'path'});
  });
}
