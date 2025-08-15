// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/src/license.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help')) {
    print('dart batch_analyse_licenses.dart <output.json>');
    print('');
    print(
      'Read all license files from the license cache directory and create an '
      'aggregated summary of the results.',
    );
    return;
  }
  final outputFileName = args.single;

  final files = Directory(
    '.dart_tool/pana/license-cache',
  ).listSync().whereType<File>().toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  final result = <String, dynamic>{};
  for (final file in files) {
    try {
      final content = file.readAsStringSync();
      final list = await detectLicenseInContent(
        content,
        relativePath: 'LICENSE',
      );
      final spdxIds = list.map((e) => e.spdxIdentifier).toList()..sort();
      final packageName = file.path
          .split('/')
          .last
          .split('LICENSE-')
          .last
          .split('.txt')
          .first;
      result[packageName] = {'spdxIds': spdxIds};
    } catch (_) {
      // TODO: also track errors
    }
  }
  await File(
    outputFileName,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
}
