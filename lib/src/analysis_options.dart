// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:meta/meta.dart';

import 'utils.dart' show yamlToJson;

/// The default `package:lints/core.yaml` analysis options configuration.
@visibleForTesting
const defaultAnalysisOptionsYaml = '''
# This is a set of core lints used to identify critical issues.
# Check out https://github.com/dart-lang/lints for more information.
#
# To learn more about customizing static analysis for your package or app,
# visit https://dart.dev/tools/analysis.

linter:
  rules:
    - avoid_empty_else
    - avoid_relative_lib_imports
    - avoid_shadowing_type_parameters
    - avoid_types_as_parameter_names
    - await_only_futures
    - camel_case_extensions
    - camel_case_types
    - collection_methods_unrelated_type
    - curly_braces_in_flow_control_structures
    - dangling_library_doc_comments
    - depend_on_referenced_packages
    - empty_catches
    - file_names
    - hash_and_equals
    - implicit_call_tearoffs
    - library_annotations
    - no_duplicate_case_values
    - no_wildcard_variable_uses
    - non_constant_identifier_names
    - null_check_on_nullable_type_parameter
    - prefer_generic_function_type_aliases
    - prefer_is_empty
    - prefer_is_not_empty
    - prefer_iterable_whereType
    - prefer_typing_uninitialized_variables
    - provide_deprecation_message
    - secure_pubspec_urls
    - strict_top_level_inference
    - type_literal_in_constant_pattern
    - unintended_html_in_doc_comment
    - unnecessary_overrides
    - unrelated_type_equality_checks
    - use_string_in_part_of_directives
    - valid_regexps
    - void_checks
''';

String? _cachedCoreLints;

/// The default analysis options configuration (in its raw yaml format).
Future<String> getDefaultAnalysisOptionsYaml() async =>
    _cachedCoreLints ??= await _getLintsCoreAnalysisOptions();

Future<String> _getLintsCoreAnalysisOptions() async {
  // Try to load local lints from the resolved package references.
  try {
    final coreLintsUri = Uri(scheme: 'package', path: 'lints/core.yaml');
    final resource = await Isolate.resolvePackageUri(coreLintsUri);
    if (resource != null) {
      final file = File.fromUri(resource);
      return await file.readAsString();
    }
  } on Exception catch (_) {
    // Gracefully handle exception to fall back to the embedded default config.
  }

  return defaultAnalysisOptionsYaml;
}

/// Update the well-known [custom] `analysis_options.yaml` content with
/// pass-through options from the package-provided [original] content.
/// Such options are:
/// - the `include:` predicate,
/// - the `formatter:` options (without any filtering),
/// - the `analyzer: / errors:` keys passing the values
/// - the `linter: / rules:` section, passing `true`/`false` values.
String updatePassthroughOptions({
  required String? original,
  required String custom,
}) {
  Map? origMap;
  if (original != null) {
    try {
      origMap = yamlToJson(original);
    } on FormatException {
      // pass, ignore broken YAML
    }
  }
  origMap ??= {};

  Map customMap;
  try {
    customMap = yamlToJson(custom) ?? <String, dynamic>{};
  } on FormatException {
    customMap = <String, dynamic>{};
  }

  final customAnalyzer =
      customMap.putIfAbsent('analyzer', () => <String, Object?>{}) as Map;

  // exclude test and example from analysis
  final existingExclude = customAnalyzer['exclude'];
  final customExclude = existingExclude is List ? existingExclude : <String>[];
  customAnalyzer['exclude'] = customExclude;

  const excludeDirs = ['test/**', 'example/**'];
  for (final dir in excludeDirs) {
    if (!customExclude.contains(dir)) {
      customExclude.add(dir);
    }
  }

  if (origMap case {'analyzer': Map origAnalyzer}) {
    if (origAnalyzer case {'errors': Map origErrors}) {
      final customErrors =
          customAnalyzer.putIfAbsent('errors', () => <String, Object?>{})
              as Map;
      customErrors.addAll(origErrors);
    }

    if (origAnalyzer case {'exclude': List origExclude}) {
      // Note: In the future we need to consider if we want to detect too wide exclude rules.
      for (var pattern in origExclude) {
        if (!customExclude.contains(pattern)) {
          customExclude.add(pattern);
        }
      }
    }

    final origExperiments = origAnalyzer['enable-experiment'];
    if (origExperiments is List && origExperiments.contains('macros')) {
      final customAnalyzer =
          customMap.putIfAbsent('analyzer', () => <String, Object?>{}) as Map;
      final customExperiments =
          customAnalyzer.putIfAbsent('enable-experiment', () => <String>[])
              as List;
      customExperiments.add('macros');
    }
  }

  if (origMap case {'linter': {'rules': Map origRules}}) {
    final customLinter = customMap.putIfAbsent(
      'linter',
      () => <String, Object?>{},
    );
    var customRules = customLinter.putIfAbsent(
      'rules',
      () => <String, Object?>{},
    );
    if (customRules is List) {
      customRules = Map<String, Object?>.fromEntries(
        customRules.map((e) => MapEntry<String, Object?>(e.toString(), true)),
      );
      customLinter['rules'] = customRules;
    }
    if (customRules is Map) {
      customRules.addAll(origRules);
    }
  }

  final origFormatter = origMap['formatter'];
  if (origFormatter is Map) {
    final customFormatter =
        customMap.putIfAbsent('formatter', () => <String, dynamic>{}) as Map;
    customFormatter.addAll(origFormatter.cast<String, dynamic>());
  }

  final newInclude = customMap['include'] ?? origMap['include'];
  if (newInclude != null) {
    customMap['include'] = newInclude;
  }

  return json.encode(customMap);
}
