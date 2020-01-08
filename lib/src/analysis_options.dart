// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:resource/resource.dart';
import 'package:yaml/yaml.dart' as yaml;

import 'package_analyzer.dart' show InspectOptions;

String _analysisOptions(String pedanticConfigPath) => '''
# Defines a default set of lint rules enforced for
# projects at Google. For details and rationale,
# see https://github.com/dart-lang/pedantic#enabled-lints.
include: $pedanticConfigPath

# For lint rules and documentation, see http://dart-lang.github.io/linter/lints.
# Uncomment to specify additional rules.
# linter:
#   rules:
#     - camel_case_types

# analyzer:
#   exclude:
#     - path/to/excluded/files/**
''';

// Keep it updated with
// https://github.com/flutter/flutter/blob/master/packages/flutter/lib/analysis_options_user.yaml
const String _flutterAnalysisOptions = '''
analyzer:
  errors:
    # treat missing required parameters as a warning (not a hint)
    missing_required_param: warning

# Source of linter options:
# https://dart-lang.github.io/linter/lints/options/options.html

linter:
  rules:
    - avoid_empty_else
    - avoid_init_to_null
    - avoid_return_types_on_setters
    - await_only_futures
    - camel_case_types
    - cancel_subscriptions
    - close_sinks
    - control_flow_in_finally
    - empty_constructor_bodies
    - empty_statements
    - hash_and_equals
    - implementation_imports
    - library_names
    - non_constant_identifier_names
    - package_api_docs
    - package_names
    - package_prefixed_library_names
    - prefer_is_not_empty
    - slash_for_doc_comments
    - super_goes_last
    - test_types_in_equals
    - throw_in_finally
    - type_init_formals
    - unnecessary_brace_in_string_interps
    - unnecessary_getters_setters
    - unnecessary_statements
    - unrelated_type_equality_checks
    - valid_regexps
''';

const _analyzerErrorKeys = <String>['uri_has_not_been_generated'];

String customizeAnalysisOptions(
    String original, bool usesFlutter, String pedanticConfigPath) {
  Map origMap;
  if (original != null) {
    try {
      origMap = yaml.loadYaml(original) as Map;
    } catch (_) {}
  }
  origMap ??= {};

  final customMap = json.decode(json.encode(yaml.loadYaml(usesFlutter
      ? _flutterAnalysisOptions
      : _analysisOptions(pedanticConfigPath))));

  final origAnalyzer = origMap['analyzer'];
  if (origAnalyzer is Map) {
    final origErrors = origAnalyzer['errors'];
    if (origErrors is Map) {
      final customAnalyzer = customMap.putIfAbsent('analyzer', () => {}) as Map;
      final customErrors =
          customAnalyzer.putIfAbsent('errors', () => {}) as Map;

      for (var key in _analyzerErrorKeys) {
        if (origErrors.containsKey(key)) {
          customErrors[key] = origErrors[key];
        }
      }
    }
  }

  return json.encode(customMap);
}

final _pedanticVersionRegExp =
    RegExp(r'package:pedantic/analysis_options\.(.*?)\.yaml');

/// Returns the content of the file with the linter ruleset content, which will
/// be linked from our custom `analysis_options.yaml`.
///
/// - Returns the content of [InspectOptions.analysisOptionsUri] when specified
///   in [inspectOptions].
/// - Returns `pedantic/analysis_options.yaml` (if nothing is linked in it)
/// - Returns the latest linked `pedantic/analysis_options.<version>.yaml`.
Future<String> getPedanticContent({
  @required InspectOptions inspectOptions,
}) async {
  final rootUri = inspectOptions?.analysisOptionsUri ??
      'package:pedantic/analysis_options.yaml';
  final rootContent = await Resource(rootUri).readAsString();
  final match = _pedanticVersionRegExp.firstMatch(rootContent);

  // When there is not match, the root content does not have URI reference,
  // the file is probably a ruleset itself.
  if (match == null) {
    return rootContent;
  }
  final versionedContent = await Resource(match.group(0)).readAsString();
  return versionedContent;
}
