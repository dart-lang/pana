// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:retry/retry.dart';
import 'package:yaml/yaml.dart' as yaml;

final _logger = Logger('analysis_options');

String? _cachedFlutterOptionsOnGithub;
String? _cachedPedanticOptionsOnGithub;

/// Returns the default analysis options (in yaml format).
Future<String> getDefaultAnalysisOptionsYaml({
  required bool usesFlutter,
  required String? flutterSdkDir,
}) async {
  if (usesFlutter) {
    return await _getFlutterAnalysisOptions(flutterSdkDir);
  } else {
    return await _getPedanticAnalysisOptions();
  }
}

Future<String> _getFlutterAnalysisOptions(String? flutterSdkDir) async {
  // try to load local file
  flutterSdkDir ??= Platform.environment['FLUTTER_ROOT'];
  if (flutterSdkDir != null &&
      flutterSdkDir.isNotEmpty &&
      await Directory(flutterSdkDir).exists()) {
    final file = File(p.join(flutterSdkDir, 'packages', 'flutter', 'lib',
        'analysis_options_user.yaml'));
    if (await file.exists()) {
      return await file.readAsString();
    }
  }

  // try to load latest from github
  if (_cachedFlutterOptionsOnGithub != null) {
    return _cachedFlutterOptionsOnGithub!;
  }
  try {
    final rs = await _httpGetWithRetry(Uri.parse(
        'https://raw.githubusercontent.com/flutter/flutter/master/packages/flutter/lib/analysis_options_user.yaml'));
    if (rs.statusCode == 200) {
      _cachedFlutterOptionsOnGithub = rs.body;
      return _cachedFlutterOptionsOnGithub!;
    }
  } catch (_) {
    // no-op
  }

  // fallback empty options
  _logger.warning('Unable to load default Flutter analysis options.');
  return '';
}

Future<String> _getPedanticAnalysisOptions() async {
  // try to load latest from github
  if (_cachedPedanticOptionsOnGithub != null) {
    return _cachedPedanticOptionsOnGithub!;
  }
  try {
    final index = await _httpGetWithRetry(Uri.parse(
        'https://raw.githubusercontent.com/google/pedantic/master/lib/analysis_options.yaml'));
    if (index.statusCode == 200) {
      final parsed = yaml.loadYaml(index.body) as Map;
      if (parsed.containsKey('include')) {
        final includeUri = parsed['include'] as String;
        if (includeUri.startsWith('package:pedantic/')) {
          final url = includeUri.replaceFirst('package:pedantic/',
              'https://raw.githubusercontent.com/google/pedantic/master/lib/');
          final rs = await _httpGetWithRetry(Uri.parse(url));
          if (rs.statusCode == 200) {
            _cachedPedanticOptionsOnGithub = rs.body;
            return _cachedPedanticOptionsOnGithub!;
          }
        }
      }
    }
  } catch (_) {
    // no-op
  }

  // fallback empty options
  _logger.warning('Unable to load default pedantic analysis options.');
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
