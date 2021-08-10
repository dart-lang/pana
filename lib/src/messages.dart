// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

String runningDartanalyzerFailed(bool usesFlutter, errorMsg) {
  final message = usesFlutter ? 'flutter analyze' : 'dart analyze .';

  return 'Running `$message` failed with the following output:\n\n'
      '```\n$errorMsg\n```\n';
}
