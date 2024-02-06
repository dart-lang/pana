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

String? _cachedLintsCoreInResolvedReferences;
String? _cachedLintsCoreOptionsOnGithub;

/// The default analysis options configuration (in its raw yaml format).
Future<String> getDefaultAnalysisOptionsYaml() async =>
    await _getLintsCoreAnalysisOptions();

Future<String> _getLintsCoreAnalysisOptions() async {
  // Try to load local lints from the resolved package references.
  if (_cachedLintsCoreInResolvedReferences case final cachedCoreLints?) {
    return cachedCoreLints;
  }

  try {
    final resource =
        await Isolate.resolvePackageUri(Uri.parse('package:lints/core.yaml'));
    final file = File.fromUri(resource!);
    final lintConfigAsString = await file.readAsString();
    _cachedLintsCoreInResolvedReferences = lintConfigAsString;
    return lintConfigAsString;
  } on Exception catch (_) {
    // Gracefully handle exception to fallback to empty options.
  }

  // Try to load latest version of the core lints from GitHub.
  if (_cachedLintsCoreOptionsOnGithub case final cachedCoreLints?) {
    return cachedCoreLints;
  }
  try {
    final rs = await _httpGetWithRetry(Uri.parse(
        'https://raw.githubusercontent.com/dart-lang/lints/main/lib/core.yaml'));
    if (rs.statusCode == 200 && rs.body.contains('rules:')) {
      final resultBody = rs.body;
      _cachedLintsCoreOptionsOnGithub = resultBody;
      return resultBody;
    }
  } on Exception catch (_) {
    // Gracefully handle exception to fallback to empty options.
  }

  // If we couldn't load the core lints,
  // log a warning and return an empty analysis config.
  _logger.warning('Unable to load default analysis options.');
  return '';
}

Future<http.Response> _httpGetWithRetry(Uri uri) async {
  return retry(
    () async {
      final rs = await http.get(uri);
      if (rs.statusCode >= 500 && rs.statusCode < 600) {
        throw http.ClientException(
            'Server returned status code: ${rs.statusCode}');
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
