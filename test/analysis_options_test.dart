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
      'linter': {'rules': hasLength(greaterThan(10))},
    });
  });

  test('passthrough for empty options', () {
    final content = updatePassthroughOptions(original: '', custom: '');
    expect(json.decode(content), <String, Object?>{
      'analyzer': {
        'exclude': ['test/**', 'example/**'],
      },
    });
  });

  test('passthrough for most options', () {
    final content = updatePassthroughOptions(
      original: '''
analyzer:
  errors:
    todo: ignore
    uri_has_not_been_generated: ignore
  enable-experiment:
    - ignored
    - macros
  exclude:
    - build/**
formatter:
  unknown_key: true
  page_width: 123
  trailing_commas: preserve
''',
      custom: '',
    );
    expect(json.decode(content), {
      'analyzer': {
        'errors': {'todo': 'ignore', 'uri_has_not_been_generated': 'ignore'},
        'enable-experiment': ['macros'],
        'exclude': ['test/**', 'example/**', 'build/**'],
      },
      'formatter': {
        'unknown_key': true,
        'page_width': 123,
        'trailing_commas': 'preserve',
      },
    });
  });

  test('passthrough analysis errors including override', () {
    final content = updatePassthroughOptions(
      original: '''
analyzer:
  errors:
    todo: ignore
    another-todo: ignore
    uri_has_not_been_generated: ignore
''',
      custom: '''
linter:
  rules:
    - todo
    - uri_has_not_been_generated
''',
    );
    expect(json.decode(content), {
      'analyzer': {
        'errors': {
          'another-todo': 'ignore',
          'todo': 'ignore',
          'uri_has_not_been_generated': 'ignore',
        },
        'exclude': ['test/**', 'example/**'],
      },
      'linter': isNotEmpty,
    });
  });

  test('passthrough linter rules including override', () {
    final content = updatePassthroughOptions(
      original: '''
linter:
  rules:
    avoid_relative_lib_imports: true
    prefer_relative_imports: false
    public_member_api_docs: false
''',
      custom: '''
linter:
  rules:
    - prefer_relative_imports
''',
    );
    expect(json.decode(content), {
      'analyzer': {
        'exclude': ['test/**', 'example/**'],
      },
      'linter': {
        'rules': {
          'avoid_relative_lib_imports': true,
          'prefer_relative_imports': false,
          'public_member_api_docs': false,
        },
      },
    });
  });

  test('update include from original', () {
    final content = updatePassthroughOptions(
      original: 'include: package:lints/other.yaml',
      custom: '',
    );
    expect(json.decode(content), {
      'include': 'package:lints/other.yaml',
      'analyzer': {
        'exclude': ['test/**', 'example/**'],
      },
    });
  });

  test('update includes from original', () {
    final content = updatePassthroughOptions(
      original:
          'include:\n'
          ' - package:lints/other.yaml\n'
          ' - package:lints/core.yaml\n',
      custom: '',
    );
    expect(json.decode(content), {
      'include': ['package:lints/other.yaml', 'package:lints/core.yaml'],
      'analyzer': {
        'exclude': ['test/**', 'example/**'],
      },
    });
  });

  test('include only in custom', () {
    final content = updatePassthroughOptions(
      original: '',
      custom: 'include: package:lints/other.yaml',
    );
    expect(json.decode(content), <String, Object?>{
      'include': 'package:lints/other.yaml',
      'analyzer': {
        'exclude': ['test/**', 'example/**'],
      },
    });
  });

  test('include does not override the value', () {
    final content = updatePassthroughOptions(
      original: 'include: package:lints/other.yaml',
      custom: 'include: package:lints/core.yaml',
    );
    expect(json.decode(content), <String, Object?>{
      'include': 'package:lints/core.yaml',
      'analyzer': {
        'exclude': ['test/**', 'example/**'],
      },
    });
  });

  test('keep include without include value', () {
    final content = updatePassthroughOptions(original: '', custom: '');
    expect(json.decode(content), <String, Object?>{
      'analyzer': {
        'exclude': ['test/**', 'example/**'],
      },
    });
  });

  test('type check', () {
    final content = updatePassthroughOptions(
      original: '''
linter:
  rules:
    a: ignore
''',
      custom: '''
linter:
  rules:
    - constant_identifier_names
    - deprecated_member_use_from_same_package
''',
    );
    expect(json.decode(content), {
      'analyzer': {
        'exclude': ['test/**', 'example/**'],
      },
      'linter': {
        'rules': {
          'constant_identifier_names': true,
          'deprecated_member_use_from_same_package': true,
          'a': 'ignore',
        },
      },
    });
  });

  test('keeps wide exclude rules too', () {
    final content = updatePassthroughOptions(
      original: '''
analyzer:
  exclude:
    - '*.dart'
    - lib/src/**.dart
    - '**/*.dart'
    - '**/*.g.dart'
    - pubspec.*
    - bin/*.dart
''',
      custom: '',
    );
    expect(json.decode(content), <String, Object?>{
      'analyzer': {
        'exclude': [
          'test/**',
          'example/**',
          '*.dart',
          'lib/src/**.dart',
          '**/*.dart',
          '**/*.g.dart',
          'pubspec.*',
          'bin/*.dart',
        ],
      },
    });
  });
}
