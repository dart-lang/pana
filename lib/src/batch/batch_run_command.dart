// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:pana/src/package_analyzer.dart';
import 'package:yaml/yaml.dart' as yaml;

import '../sdk_env.dart' show SdkConfig, ToolEnvironment;
import '../utils.dart' show withTempDir;

import 'batch_model.dart';

/// Runs pana on the selected packages.
class BatchRunCommand extends Command<void> {
  @override
  String get name => 'run';

  @override
  String get description => 'Runs pana on the selected packages.';

  BatchRunCommand() {
    argParser
      ..addOption(
        'packages',
        help:
            'The file that contains the list of packages, or the comma separated names.',
      )
      ..addOption(
        'config',
        help: 'The configuration file to use.',
      )
      ..addOption(
        'output',
        help: 'Write the result to file (stdout otherwise).',
      );
  }

  @override
  Future<void> run() async {
    final packages = await _parsePackages(argResults!['packages'] as String);
    final config = await _parseConfig(argResults!['config'] as String);
    final output = argResults!['output'] as String?;

    await withTempDir((tempDir) async {
      final env = await _initToolEnv(config, tempDir);

      final results = <String, dynamic>{};

      for (final package in packages) {
        dynamic result;
        try {
          print('analyzing $package...');
          final summary = await PackageAnalyzer(env).inspectPackage(package);
          result = summary.report?.grantedPoints;
        } catch (e, st) {
          result = '$e\n$st';
        }
        if (result is! int) {
          print('$package: $result');
        }
        results[package] = result;
      }

      final formatted = const JsonEncoder.withIndent('  ').convert(results);
      if (output == null) {
        print(formatted);
      } else {
        await File(output).writeAsString(formatted);
      }
    });
  }

  Future<List<String>> _parsePackages(String arg) async {
    final file = File(arg);
    if (file.existsSync()) {
      return await file.readAsLines();
    }
    return arg.split(',').map((e) => e.trim()).toList();
  }

  Future<BatchConfig> _parseConfig(String? arg) async {
    if (arg == null) {
      return BatchConfig();
    }
    final file = File(arg);
    if (file.existsSync()) {
      var content = await file.readAsString();
      if (file.path.endsWith('.yaml')) {
        content = json.encode(yaml.loadYaml(content));
      }
      return BatchConfig.fromJson(json.decode(content) as Map<String, dynamic>);
    }
    throw ArgumentError('Unable to load config: `$arg`.');
  }

  Future<ToolEnvironment> _initToolEnv(
      BatchConfig config, String pubCache) async {
    return await ToolEnvironment.create(
      dartSdkConfig: SdkConfig(
        rootPath: config.dartSdk,
        environment: config.environment ?? const {},
      ),
      flutterSdkConfig: SdkConfig(
        rootPath: config.flutterSdk,
        environment: config.environment ?? const {},
      ),
      pubCacheDir: pubCache,
    );
  }
}
