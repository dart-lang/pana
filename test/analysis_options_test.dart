// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:test/test.dart';

import 'package:pana/src/analysis_options.dart';

void main() {
  test('flutter without original', () {
    expect(JSON.decode(customizeAnalysisOptions(null, true)), {
      'analyzer': {
        'strong-mode': true,
        'language': {
          'enableSuperMixins': true,
          'enableStrictCallChecks': true,
          'enableAssertInitializer': true
        },
        'errors': {
          'todo': 'ignore',
          'missing_return': 'warning',
          'missing_required_param': 'warning'
        },
      },
      'linter': {
        'rules': [
          'camel_case_types',
          'hash_and_equals',
          'iterable_contains_unrelated_type',
          'list_remove_unrelated_type',
          'unrelated_type_equality_checks',
          'valid_regexps',
        ],
      },
    });
  });

  test('not whitelisted analyzer error', () {
    final original = '''
analyzer:
  errors:
    todo: ignore
''';
    expect(JSON.decode(customizeAnalysisOptions(original, false)), {
      'analyzer': {
        'strong-mode': true,
        'errors': {},
      },
      'linter': {
        'rules': [
          'camel_case_types',
          'hash_and_equals',
          'iterable_contains_unrelated_type',
          'list_remove_unrelated_type',
          'unrelated_type_equality_checks',
          'valid_regexps',
        ],
      },
    });
  });

  test('whitelisted analyzer error', () {
    final original = '''
analyzer:
  errors:
    uri_has_not_been_generated: ignore
''';
    expect(JSON.decode(customizeAnalysisOptions(original, false)), {
      'analyzer': {
        'strong-mode': true,
        'errors': {
          'uri_has_not_been_generated': 'ignore',
        },
      },
      'linter': {
        'rules': [
          'camel_case_types',
          'hash_and_equals',
          'iterable_contains_unrelated_type',
          'list_remove_unrelated_type',
          'unrelated_type_equality_checks',
          'valid_regexps',
        ],
      },
    });
  });
}
