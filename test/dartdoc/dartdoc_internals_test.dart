// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/dartdoc/dartdoc_internals.dart';
import 'package:test/test.dart';

void main() {
  group('dartdoc internals', () {
    test('isHrefALibrary: negative', () async {
      expect(isHrefALibrary(null), false);
      expect(isHrefALibrary(''), false);
      expect(isHrefALibrary('index.html'), false);
      expect(isHrefALibrary('retry.html'), false);
      expect(isHrefALibrary('retry/retry.html'), false);
      expect(isHrefALibrary('a/b'), false);
    });

    test('isHrefALibrary: positive', () async {
      expect(isHrefALibrary('x/x-library.html'), true);
      expect(isHrefALibrary('x'), true);
      expect(isHrefALibrary('x/'), true);
    });
  });
}
