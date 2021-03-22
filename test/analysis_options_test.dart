// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' as yaml;

import 'package:pana/src/analysis_options.dart';
import 'package:pana/src/package_analyzer.dart' show InspectOptions;

void main() {
  test('default pedantic options', () async {
    final content = await getPedanticContent(inspectOptions: InspectOptions());
    expect(content, contains('linter:'));
    expect(content, contains('rules:'));
    expect(content, isNot(contains('avoid_empty_else'))); // removed recently
    expect(content, contains('avoid_init_to_null'));
    expect(content, contains('prefer_is_empty'));
    expect(content, contains('prefer_single_quotes')); // in 1.9.0
  });

  test('specific pedantic options', () async {
    final content = await getPedanticContent(
        inspectOptions: InspectOptions(
            analysisOptionsUri:
                'package:pedantic/analysis_options.1.8.0.yaml'));
    expect(content, contains('linter:'));
    expect(content, contains('rules:'));
    expect(content, contains('avoid_empty_else'));
    expect(content, contains('prefer_is_empty'));
    expect(content, isNot(contains('prefer_single_quotes'))); // only from 1.9.0
  });

  test('default options', () {
    expect(
      json.decode(customizeAnalysisOptions(
          null, false, '/path/to/pedantic/analysis_options.yaml')),
      {
        'include': '/path/to/pedantic/analysis_options.yaml',
      },
    );
  });

  test('flutter without original', () async {
    // Resulting options file should match the default Flutter analysis_options.yaml
    final rs = await http.get(Uri.parse(
        'https://raw.githubusercontent.com/flutter/flutter/master/packages/flutter/lib/analysis_options_user.yaml'));
    final body = json.decode(json.encode(yaml.loadYaml(rs.body)));
    expect(
      json.decode(customizeAnalysisOptions(
          null, true, '/path/to/pedantic/analysis_options.yaml')),
      body,
    );
  });

  test('not allowed analyzer error', () {
    final original = '''
analyzer:
  errors:
    todo: ignore
''';
    expect(
      json.decode(customizeAnalysisOptions(
          original, false, '/path/to/pedantic/analysis_options.yaml')),
      {
        'include': '/path/to/pedantic/analysis_options.yaml',
        'analyzer': {
          'errors': {},
        },
      },
    );
  });

  test('allowed analyzer error', () {
    final original = '''
analyzer:
  errors:
    uri_has_not_been_generated: ignore
''';
    expect(
      json.decode(customizeAnalysisOptions(
          original, false, '/path/to/pedantic/analysis_options.yaml')),
      {
        'include': '/path/to/pedantic/analysis_options.yaml',
        'analyzer': {
          'errors': {
            'uri_has_not_been_generated': 'ignore',
          },
        },
      },
    );
  });
}
