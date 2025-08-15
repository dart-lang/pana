// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart' as yaml;

import '../package_analyzer.dart';
import '../sdk_env.dart' show SdkConfig, ToolEnvironment;
import '../utils.dart' show withTempDir;
import 'batch_model.dart';

/// Compares pana outcomes on the selected packages.
class BatchCompareCommand extends Command<void> {
  @override
  String get name => 'compare';

  @override
  String get description => 'Compare pana outcomes on the selected packages.';

  BatchCompareCommand() {
    argParser
      ..addOption(
        'packages',
        help:
            'The file that contains the list of packages, or the comma separated names.',
      )
      ..addOption(
        'experiment',
        help: 'The configuration file of the new features.',
      )
      ..addOption(
        'control',
        help: 'The configuration file of the old features.',
      )
      ..addOption(
        'output',
        help: 'Write the result to file (stdout otherwise).',
      );
  }

  @override
  Future<void> run() async {
    final packages = await _parsePackages(argResults!['packages'] as String);
    final experimentConfig = await _parseConfig(
      argResults!['experiment'] as String,
    );
    final controlConfig = await _parseConfig(argResults!['control'] as String);
    final output = argResults!['output'] as String?;

    await withTempDir((tempDir) async {
      final experimentEnv = await _initToolEnv(experimentConfig, tempDir);
      final controlEnv = await _initToolEnv(controlConfig, tempDir);

      var unchangedCount = 0;
      final increased = <String, int>{};
      final decreased = <String, int>{};

      for (final package in packages) {
        final expSummary = await PackageAnalyzer(
          experimentEnv,
        ).inspectPackage(package);
        final controlSummary = await PackageAnalyzer(
          controlEnv,
        ).inspectPackage(package);

        final diff =
            (expSummary.report?.grantedPoints ?? 0) -
            (controlSummary.report?.grantedPoints ?? 0);
        print('$package: $diff');

        if (diff == 0) {
          unchangedCount++;
        } else if (diff > 0) {
          increased[package] = diff;
        } else {
          decreased[package] = diff;
        }
      }

      final result = BatchResult(
        unchangedCount: unchangedCount,
        increased: BatchChanged(count: increased.length, packages: increased),
        decreased: BatchChanged(count: decreased.length, packages: decreased),
      );

      final formatted = const JsonEncoder.withIndent(
        '  ',
      ).convert(result.toJson());
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
    BatchConfig config,
    String pubCache,
  ) async {
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
