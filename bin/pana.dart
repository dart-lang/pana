#!/usr/bin/env dart --checked
// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart' as log;
import 'package:pana/pana.dart';

const defaultHostedUrl = 'https://pub.dev';

final _parser = ArgParser()
  ..addOption('flutter-sdk', help: 'The directory of the Flutter SDK.')
  ..addFlag('json',
      abbr: 'j',
      help: 'Output log items as JSON.',
      defaultsTo: false,
      negatable: false)
  ..addOption('source',
      abbr: 's',
      help:
          'The source where the package is located (hosted on $defaultHostedUrl, or local directory path).',
      allowed: ['hosted', 'path'],
      defaultsTo: 'hosted')
  ..addOption('hosted-url',
      help: 'The server that hosts <package>.', defaultsTo: defaultHostedUrl)
  ..addOption('line-length',
      abbr: 'l', help: 'The line length to use with dartfmt.')
  ..addOption('verbosity',
      help: 'Configure the details in the output.',
      allowed: ['compact', 'normal', 'verbose'],
      defaultsTo: 'normal')
  ..addFlag('scores', help: 'Include scores in the output JSON.')
  ..addFlag('warning',
      help:
          'Shows the warning message before potentially destructive operation.',
      negatable: true,
      defaultsTo: true);

void _printHelp({String errorMessage}) {
  if (errorMessage != null) {
    print(red.wrap(errorMessage));
    print('');
  }
  print('''Usage: pana [<options>] <published package name> [<version>]
       pana [<options>] --source path <local directory>

Options:
${LineSplitter.split(_parser.usage).map((l) => '  $l').join('\n')}''');
}

Future main(List<String> args) async {
  ArgResults result;
  try {
    result = _parser.parse(args);
  } on FormatException catch (e) {
    _printHelp(errorMessage: e.message);
    exitCode = ExitCode.usage.code;
    return;
  }

  final isJson = result['json'] as bool;
  final showWarning = result['warning'] as bool;
  final showScores = result['scores'] as bool;

  final source = result['source'];
  final verbosity = Verbosity.values
      .firstWhere((v) => v.toString().split('.').last == result['verbosity']);
  String firstArg(String error) {
    if (result.rest.isEmpty) {
      _printHelp(errorMessage: error);
      exit(ExitCode.usage.code);
    }
    return result.rest.first;
  }

  log.Logger.root.level = log.Level.ALL;

  if (isJson) {
    log.Logger.root.onRecord.listen((log) {
      var map = <String, Object>{};

      if (log.loggerName.isNotEmpty) {
        map['logName'] = log.loggerName;
      }

      map.addAll({
        'level': log.level.name,
        'message': log.message,
      });

      if (log.error != null) {
        map['error'] = log.error.toString();
      }

      if (log.stackTrace != null) {
        map['stackTrace'] = log.stackTrace.toString();
      }
      stderr.writeln(json.encode(map));
    });
  } else {
    log.Logger.root.onRecord.listen(_logWriter);
  }

  // Docker is WEIRD
  // The SIGTERM signal sent to `docker run...` DOES propagate a signal to the
  // running process. But...
  //   * It is received as SIGINT
  //   * It won't terminate the Dart process either – *BUT* we can listen for it
  // So this is how we do "clean" shutdown when running in Docker.
  var subscription = getSignals().listen((sig) async {
    log.Logger.root.severe('Received signal `$sig` – terminating.');
    exit(130);
  });

  var tempDir = Directory.systemTemp
      .createTempSync('pana.${DateTime.now().millisecondsSinceEpoch}.');

  // Critical to make sure analyzer paths align well
  var tempPath = await tempDir.resolveSymbolicLinks();

  try {
    final pubHostedUrl = result['hosted-url'] as String;
    final analyzer = await PackageAnalyzer.create(
      pubCacheDir: tempPath,
      flutterDir: result['flutter-sdk'] as String,
    );
    final options = InspectOptions(
      verbosity: verbosity,
      pubHostedUrl: pubHostedUrl,
      lineLength: int.tryParse(result['line-length'] as String ?? ''),
    );
    try {
      Summary summary;
      if (source == 'hosted') {
        final package = firstArg('No package was provided.');
        String version;
        if (result.rest.length > 1) {
          version = result.rest[1];
        }
        if (pubHostedUrl != defaultHostedUrl && version == null) {
          _printHelp(
              errorMessage:
                  'Version must be specified when using --hosted-url option.');
          return;
        }
        summary = await analyzer.inspectPackage(package,
            version: version, options: options);
      } else if (source == 'path') {
        final path = firstArg('No path was provided.');
        final absolutePath = await Directory(path).resolveSymbolicLinks();
        if (showWarning) {
          log.Logger.root
              .warning('pana might update or modify files in `$path`.\n'
                  'Analysis will begin in 15 seconds, hit CTRL+C to abort it.\n'
                  'To remove this message, use `--no-warning`.');
          await Future.delayed(const Duration(seconds: 15));
        }
        summary = await analyzer.inspectDir(absolutePath, options: options);
      }
      final map = summary.toJson();
      if (showScores) {
        map['scores'] = {
          'health': _calculateScore(summary.health?.suggestions),
          'maintenance': _calculateScore(summary.maintenance?.suggestions),
        };
      }
      print(prettyJson(map));
    } catch (e, stack) {
      final message = "Problem analyzing ${result.rest.join(' ')}";
      final errorStr = e.toString();
      final isInputError = errorStr.contains("Package doesn't exist");
      final showStack = !isInputError;
      log.Logger.root.shout(message, e, showStack ? stack : null);
      exitCode = 1;
    }
  } finally {
    tempDir.deleteSync(recursive: true);
  }

  await subscription.cancel();
}

void _logWriter(log.LogRecord record) {
  var wroteHeader = false;

  var msg = LineSplitter.split([record.message, record.error, record.stackTrace]
          .where((e) => e != null)
          .join('\n'))
      .map((l) {
    String prefix;
    if (wroteHeader) {
      prefix = '';
    } else {
      wroteHeader = true;
      prefix = record.level.toString();
    }
    return '${prefix.padRight(10)} $l';
  }).join('\n');

  overrideAnsiOutput(stderr.supportsAnsiEscapes, () {
    stderr.writeln(darkGray.wrap(msg));
  });
}

double _calculateScore(List<Suggestion> suggestions) {
  if (suggestions == null || suggestions.isEmpty) {
    return 100.0;
  }
  final score = max(0.0,
      suggestions?.fold<double>(100.0, (d, s) => d - (s.score ?? 0)) ?? 0.0);
  return (score * 100.0).round() / 100.0;
}
