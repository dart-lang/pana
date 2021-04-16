// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:yaml/yaml.dart' as yaml;
import 'package:test/test.dart';

import 'package:pana/src/analysis_options.dart';

void main() {
  test('default pedantic options', () async {
    final content = await getDefaultAnalysisOptionsYaml(
        usesFlutter: false, flutterSdkDir: null);
    expect(content, contains('linter:'));
    expect(content, contains('rules:'));
    expect(content, isNot(contains('avoid_empty_else'))); // removed recently
    expect(content, contains('avoid_init_to_null'));
    expect(content, contains('prefer_is_empty'));
    expect(content, contains('prefer_single_quotes')); // in 1.9.0
    expect(json.decode(json.encode(yaml.loadYaml(content))), {
      'linter': {
        'rules': hasLength(greaterThan(10)),
      },
    });
  });

  test('default Flutter options', () async {
    final content = await getDefaultAnalysisOptionsYaml(
        usesFlutter: true, flutterSdkDir: null);
    expect(json.decode(json.encode(yaml.loadYaml(content))), {
      'analyzer': {
        'errors': {
          'missing_required_param': 'warning',
        },
      },
      'linter': {
        'rules': hasLength(greaterThan(10)),
      },
    });
  });

  test('passthrough for empty options', () {
    final content = updatePassthroughOptions(original: '', custom: '');
    expect(json.decode(content), {});
  });

  test('passthrough for some options', () {
    final content = updatePassthroughOptions(original: '''
analyzer:
  errors:
    todo: ignore
    uri_has_not_been_generated: ignore
''', custom: '');
    expect(json.decode(content), {
      'analyzer': {
        'errors': {
          'uri_has_not_been_generated': 'ignore',
        },
      },
    });
  });
}
