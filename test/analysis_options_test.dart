// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:pana/src/analysis_options.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' as yaml;

void main() {
  test('default options', () async {
    final content = await getDefaultAnalysisOptionsYaml();
    expect(content, contains('linter:'));
    expect(content, contains('rules:'));
    expect(content, contains('avoid_empty_else'));
    expect(content, isNot(contains('avoid_init_to_null')));
    expect(json.decode(json.encode(yaml.loadYaml(content))), {
      'linter': {
        'rules': hasLength(greaterThan(10)),
      },
    });
  });

  test('passthrough for empty options', () {
    final content = updatePassthroughOptions(original: '', custom: '');
    expect(json.decode(content), <String, Object?>{});
  });

  test('passthrough for some options', () {
    final content = updatePassthroughOptions(original: '''
analyzer:
  errors:
    todo: ignore
    uri_has_not_been_generated: ignore
  enable-experiment:
    - ignored
    - macros
formatter:
  unknown_key: true
  page_width: 123
  trailing_commas: preserve
''', custom: '');
    expect(json.decode(content), {
      'analyzer': {
        'errors': {
          'uri_has_not_been_generated': 'ignore',
        },
        'enable-experiment': [
          'macros',
        ],
      },
      'formatter': {
        'unknown_key': true,
        'page_width': 123,
        'trailing_commas': 'preserve',
      },
    });
  });
}
