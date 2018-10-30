// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:pana/src/messages.dart';

void main() {
  group('buildSample', () {
    String format(int value) => '${value}x$value';

    test('no items', () {
      expect(buildSample(<int>[].map(format)), '');
    });

    test('1 item', () {
      expect(buildSample(<int>[1].map(format)), '1x1');
    });

    test('2 items', () {
      expect(buildSample(<int>[1, 2].map(format)), '1x1, 2x2');
    });

    test('3 items', () {
      expect(buildSample(<int>[1, 2, 3].map(format)), '1x1, 2x2, 3x3');
    });

    test('4 items', () {
      expect(
          buildSample(<int>[1, 2, 3, 4].map(format)), '1x1, 2x2 and 2 more.');
    });

    test('10 items', () {
      expect(buildSample(List.generate(10, (i) => i + 1).map(format)),
          '1x1, 2x2 and 8 more.');
    });
  });
}
