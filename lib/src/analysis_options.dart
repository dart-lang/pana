// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:retry/retry.dart';
import 'package:yaml/yaml.dart' as yaml;

final _logger = Logger('analysis_options');

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
    // Gracefully handle exception to fall back to an empty config.
  }

  // Try to load latest version of the core lints from GitHub.
  try {
    final rs = await _httpGetWithRetry(
      Uri.parse(
        'https://raw.githubusercontent.com/dart-lang/lints/main/lib/core.yaml',
      ),
    );
    if (rs.statusCode == 200 && rs.body.contains('rules:')) {
      return rs.body;
    }
  } on Exception catch (_) {
    // Gracefully handle exception to fall back to an empty config.
  }

  // If we couldn't load the core lints,
  // log a warning and fall back to an empty analysis config.
  _logger.warning('Unable to load the core set of analysis options.');
  return '';
}

Future<http.Response> _httpGetWithRetry(Uri uri) async {
  return retry(
    () async {
      final rs = await http.get(uri);
      if (rs.statusCode >= 500 && rs.statusCode < 600) {
        throw http.ClientException(
          'Server returned status code: ${rs.statusCode}',
        );
      }
      return rs;
    },
    retryIf: (e) => e is SocketException || e is http.ClientException,
    maxAttempts: 3,
    delayFactor: const Duration(seconds: 2),
  );
}

const _analyzerErrorKeys = <String>['uri_has_not_been_generated'];

/// Update the well-known [custom] `analysis_options.yaml` content with
/// pass-through options from the package-provided [original] content.
/// Such options are:
/// - the `include:` predicate,
/// - the `formatter:` options (without any filtering),
/// - the `analyzer: / errors:` keys passing the values if
///   their key is not present in [custom] or are in [_analyzerErrorKeys],
/// - the `linter: / rules:` section, passing `true`/`false`
///   values if their key is not present in [custom].
String updatePassthroughOptions({
  required String? original,
  required String custom,
  bool useAnalysisIncludes = false,
}) {
  Map? origMap;
  if (original != null) {
    try {
      origMap = yaml.loadYaml(original) as Map;
    } catch (_) {}
  }
  origMap ??= {};

  final customMap =
      (json.decode(json.encode(yaml.loadYaml(custom))) as Map?) ??
      <String, dynamic>{};

  final appliedCustomRules = _extractAppliedRules(customMap);

  if (origMap case {'analyzer': Map origAnalyzer}) {
    if (origAnalyzer case {'errors': Map origErrors}) {
      final customAnalyzer =
          customMap.putIfAbsent('analyzer', () => <String, Object?>{}) as Map;
      final customErrors =
          customAnalyzer.putIfAbsent('errors', () => <String, Object?>{})
              as Map;

      for (var entry in origErrors.entries) {
        if (_analyzerErrorKeys.contains(entry.key) ||
            !appliedCustomRules.contains(entry.key)) {
          customErrors[entry.key] = entry.value;
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
      for (var e in origRules.entries) {
        if (appliedCustomRules.contains(e.key)) {
          continue;
        }
        customRules[e.key.toString()] = e.value;
      }
    }
  }

  final origFormatter = origMap['formatter'];
  if (origFormatter is Map) {
    final customFormatter =
        customMap.putIfAbsent('formatter', () => <String, dynamic>{}) as Map;
    customFormatter.addAll(origFormatter.cast<String, dynamic>());
  }

  final newInclude =
      customMap['include'] ?? (useAnalysisIncludes ? origMap['include'] : null);
  if (newInclude != null) {
    customMap['include'] = newInclude;
  }

  return json.encode(customMap);
}

Set<String> _extractAppliedRules(Map map) {
  final appliedRules = <String>{};
  if (map case {'linter': {'rules': List rules}}) {
    appliedRules.addAll(rules.map((e) => e.toString()));
  }
  if (map case {'linter': {'rules': Map rules}}) {
    appliedRules.addAll(rules.keys.map((e) => e.toString()));
  }
  if (map case {'analyzer': {'errors': Map errors}}) {
    appliedRules.addAll(errors.keys.map((e) => e.toString()));
  }
  return appliedRules;
}
