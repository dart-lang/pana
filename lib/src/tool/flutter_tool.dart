// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Removes intermittent messages that may be mixed with regular Flutter output.
String stripIntermittentFlutterMessages(String content) {
  // filter for concurrent flutter execution
  final waitingForString = 'Waiting for another flutter';
  if (content.contains(waitingForString)) {
    content = content
        .split('\n')
        .where((e) => !e.contains(waitingForString))
        .join('\n');
  }
  // filter for welcome screen
  if (content.contains('Welcome to Flutter!')) {
    final lines = content.split('\n');
    final separator = lines.indexWhere((l) => l.trim().isEmpty);
    if (separator >= 0) {
      content = lines.take(separator).join('\n');
    }
  }
  return content;
}
