// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

/// Returns the candidates in priority order to display under the 'Example' tab.
List<String> exampleFileCandidates(String package) {
  return <String>[
    'example/example.md',
    'example/lib/main.dart',
    'example/main.dart',
    'example/lib/$package.dart',
    'example/$package.dart',
    'example/lib/${package}_example.dart',
    'example/${package}_example.dart',
    'example/lib/example.dart',
    'example/example.dart',
    'example/README.md',
  ];
}

/// Returns a markdown-formatted error message for pubspec.yaml parse error.
String pubspecParseError(Object error) {
  // TODO: remove this after json_annotation is updated with CheckedFromJsonException.toString()
  var message = error.toString();
  if (error is CheckedFromJsonException) {
    final msg =
        error.message ?? 'Error with `${error.key}`: ${error.innerError}';
    message = 'CheckedFromJsonException: $msg';
  }
  return 'Error while parsing `pubspec.yaml`.\n\n'
      'Parsing throws an exception:\n\n```\n$message\n```';
}
