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

String updatePassthroughOptions({
  required String? original,
  required String custom,
  bool keepInclude = false,
}) {
  Map? origMap;
  if (original != null) {
    try {
      origMap = yaml.loadYaml(original) as Map;
    } catch (_) {}
  }
  origMap ??= {};

  final customMap =
      json.decode(json.encode(yaml.loadYaml(custom))) ?? <String, dynamic>{};

  final origAnalyzer = origMap['analyzer'];
  if (origAnalyzer is Map) {
    final origErrors = origAnalyzer['errors'];
    if (origErrors is Map) {
      final customAnalyzer =
          customMap.putIfAbsent('analyzer', () => <String, Object?>{}) as Map;
      final customErrors =
          customAnalyzer.putIfAbsent('errors', () => <String, Object?>{})
              as Map;

      for (var key in _analyzerErrorKeys) {
        if (origErrors.containsKey(key)) {
          customErrors[key] = origErrors[key];
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

  final origLinter = origMap['linter'];
  if (origLinter is Map) {
    final origRules = origLinter['rules'];
    if (origRules is Map) {
      final customLinter = customMap.putIfAbsent(
        'linter',
        () => <String, Object?>{},
      );
      var customRules = customLinter.putIfAbsent(
        'rules',
        () => <String, Object?>{},
      );
      if (customRules is List) {
        customRules = Map.fromEntries(
          customRules.map((e) => MapEntry(e, true)),
        );
        customLinter['rules'] = customRules;
      }
      if (customRules is Map) {
        for (var e in origRules.entries) {
          if (customRules.containsKey(e.key)) {
            continue;
          }
          customRules[e.key] = e.value;
        }
      }
    }
  }

  final origFormatter = origMap['formatter'];
  if (origFormatter is Map) {
    final customFormatter =
        customMap.putIfAbsent('formatter', () => <String, dynamic>{}) as Map;
    customFormatter.addAll(origFormatter.cast<String, dynamic>());
  }

  if (keepInclude) {
    final newInclude = customMap['include'] ?? origMap['include'];
    if (newInclude != null) {
      customMap['include'] = newInclude;
    }
  }

  return json.encode(customMap);
}
