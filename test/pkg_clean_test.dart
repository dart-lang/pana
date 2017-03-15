// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:pkg_clean/src/summary.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  test('pub parse', () {
    var summary = new PubSummary(0, _pubUpgradeOutput, '');

    expect(summary.stdout, _pubUpgradeOutput);

    expect(summary.packageVersions, hasLength(61));
    expect(summary.packageVersions,
        containsPair('args', new Version.parse('0.13.7')));
    expect(summary.packageVersions,
        containsPair('analyzer', new Version.parse('0.29.8')));

    expect(summary.availableVersions, hasLength(7));
    expect(summary.availableVersions,
        containsPair('analyzer', new Version.parse('0.30.0-alpha.1')));
  });
}

final _pubUpgradeOutput =
    r'''IO  : Finished /Users/kevmoo/homebrew/Cellar/dart/1.23.0-dev.5.0/libexec/bin/dart. Exit code 0.
    | Nothing output on stdout.
    | Nothing output on stderr.
FINE: Precompiling executables finished (2.071s).

MSG : Resolving dependencies...
MSG : + analyzer 0.29.8 (0.30.0-alpha.1 available)
    | + args 0.13.7
    | + async 1.13.2
    | + barback 0.15.2+9
    | + boolean_selector 1.0.2
    | + build 0.5.0 (0.7.2 available)
    | + build_test 0.2.0+1 (0.4.1 available)
    | + charcode 1.1.1
    | + cli_util 0.0.1+2
    | + code_builder 1.0.0-alpha+5 (1.0.0-beta+5 available)
    | + code_transformers 0.5.1
    | + collection 1.13.0
    | + convert 2.0.1
    | + crypto 2.0.1
    | + csslib 0.13.4
    | + dart_style 0.2.16
    | + fixnum 0.10.5
    | + func 0.1.1
    | + glob 1.1.3
    | + html 0.13.1
    | + http 0.11.3+12
    | + http_multi_server 2.0.3
    | + http_parser 3.1.1
    | + intl 0.14.0
    | + isolate 1.0.0
    | + js 0.6.1
    | + logging 0.11.3+1
    | + matcher 0.12.0+2
    | + meta 1.0.4
    | + mime 0.9.3
    | + mockito 1.0.1 (2.0.2 available)
    | + observable 0.14.0+1 (0.20.4 available)
    | + package_config 1.0.0
    | + package_resolver 1.0.2
    | + path 1.4.1
    | + plugin 0.2.0
    | + pool 1.3.0
    | + protobuf 0.5.3
    | + pub_semver 1.3.2
    | + quiver 0.24.0
    | + shelf 0.6.7+2
    | + shelf_packages_handler 1.0.0
    | + shelf_static 0.2.4
    | + shelf_web_socket 0.2.1
    | + source_gen 0.5.3+2 (0.5.4+2 available)
    | + source_map_stack_trace 1.1.4
    | + source_maps 0.10.3
    | + source_span 1.3.1
    | + stack_trace 1.7.3
    | + stream_channel 1.6.1
    | + string_scanner 1.0.1
    | + term_glyph 1.0.0
    | + test 0.12.20+3
    | + transformer_test 0.2.1+1
    | + typed_data 1.1.3
    | + utf 0.9.0+3
    | + watcher 0.9.7+3
    | + web_socket_channel 1.0.4
    | + when 0.2.0
    | + which 0.1.3
    | + yaml 2.1.12
MSG : Downloading code_builder 1.0.0-alpha+5...
MSG : Downloading build_test 0.2.0+1...
MSG : Changed 61 dependencies!
MSG : Precompiling dependencies...
MSG : Loading source assets...
MSG : Precompiled dart_style and intl.''';
