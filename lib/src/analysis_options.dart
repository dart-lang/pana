// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:yaml/yaml.dart' as yaml;

const String _analysisOptions = '''
analyzer:
  strong-mode: true

# Source of linter options:
# http://dart-lang.github.io/linter/lints/options/options.html

linter:
  rules:
    - camel_case_types
    - hash_and_equals
    - iterable_contains_unrelated_type
    - list_remove_unrelated_type
    - unrelated_type_equality_checks
    - valid_regexps
''';

// Keep it updated with
// https://github.com/flutter/flutter/blob/master/packages/flutter/lib/analysis_options_user.yaml
const String _flutterAnalysisOptions = '''
analyzer:
  language:
    enableStrictCallChecks: true
    enableSuperMixins: true
    enableAssertInitializer: true
  strong-mode: true
  errors:
    # treat missing required parameters as a warning (not a hint)
    missing_required_param: warning
    # treat missing returns as a warning (not a hint)
    missing_return: warning
    # allow having TODOs in the code
    todo: ignore

# Source of linter options:
# http://dart-lang.github.io/linter/lints/options/options.html

linter:
  rules:
    - camel_case_types
    - hash_and_equals
    - iterable_contains_unrelated_type
    - list_remove_unrelated_type
    - unrelated_type_equality_checks
    - valid_regexps
''';

const _analyzerErrorKeys = const <String>['uri_has_not_been_generated'];

String customizeAnalysisOptions(String original, bool usesFlutter) {
  Map origMap;
  if (original != null) {
    try {
      origMap = yaml.loadYaml(original);
    } catch (_) {}
  }
  origMap ??= {};

  final customMap = json.decode(json.encode(
      yaml.loadYaml(usesFlutter ? _flutterAnalysisOptions : _analysisOptions)));

  final origAnalyzer = origMap['analyzer'];
  if (origAnalyzer is Map) {
    final origErrors = origAnalyzer['errors'];
    if (origErrors is Map) {
      final Map customAnalyzer = customMap.putIfAbsent('analyzer', () => {});
      final Map customErrors = customAnalyzer.putIfAbsent('errors', () => {});

      for (var key in _analyzerErrorKeys) {
        if (origErrors.containsKey(key)) {
          customErrors[key] = origErrors[key];
        }
      }
    }
  }

  return json.encode(customMap);
}
