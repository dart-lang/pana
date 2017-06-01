// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:math';
import 'package:pana/src/scoring.dart';
import 'package:test/test.dart';

void main() {
  group('summary', () {
    test('empty', () {
      expect(() => new Summary([]), throwsArgumentError);
    });

    test('trivial', () {
      var summary = new Summary([5]);

      expect(summary.min, 5);
      expect(summary.max, 5);
      expect(summary.mean, 5);
    });

    test('easy', () {
      var summary = new Summary([5, 6, 7]);

      expect(summary.min, 5);
      expect(summary.max, 7);
      expect(summary.mean, 6);
    });

    group('scoring', () {
      test('0.75 average', () {
        // If the average is ~0.75 the result from `bezierScore` will
        // ~= `simpleScore`
        var summary = new Summary([0, 7.5, 7.5, 9, 9, 9, 8, 10]);

        expect(summary.min, 0);
        expect(summary.max, 10);
        expect(summary.mean, 7.5);

        expect(() => summary.simpleScore(-1), throwsRangeError);
        expect(() => summary.simpleScore(11), throwsRangeError);

        expect(summary.simpleScore(10), 1);
        expect(summary.simpleScore(7.5), 0.75);
        expect(summary.simpleScore(5), 0.5);

        expect(summary.bezierScore(10), 1);
        expect(summary.bezierScore(7.5), closeTo(0.75, epsilon));
        expect(summary.bezierScore(5), 0.5);
      });

      test('simple', () {
        var summary = new Summary(new Iterable.generate(101, (i) => 50 + i));
        expect(summary.min, 50);
        expect(summary.max, 150);
        expect(summary.mean, 100);

        expect(() => summary.simpleScore(49), throwsRangeError);
        expect(() => summary.simpleScore(151), throwsRangeError);

        expect(summary.simpleScore(150), 1);
        expect(summary.simpleScore(100), 0.5);
        expect(summary.simpleScore(50), 0);

        expect(summary.bezierScore(150), 1);
        expect(summary.bezierScore(100), 0.6875);
        expect(summary.bezierScore(50), 0);
      });

      test('negative', () {
        var summary = new Summary(new Iterable.generate(101, (i) => i - 200));
        expect(summary.min, -200);
        expect(summary.max, -100);
        expect(summary.mean, -150);

        expect(() => summary.simpleScore(49), throwsRangeError);
        expect(() => summary.simpleScore(151), throwsRangeError);

        expect(summary.simpleScore(-200), 0);
        expect(summary.simpleScore(-150), 0.5);
        expect(summary.simpleScore(-100), 1.0);

        expect(summary.bezierScore(-200), 0);
        expect(summary.bezierScore(-150), 0.6875);
        expect(summary.bezierScore(-100), 1);
      });

      test('random', () {
        var rnd = new Random();
        for (var x = 0; x < 1000; x++) {
          var summary = new Summary(
              new Iterable.generate(1000, (i) => 50 - rnd.nextDouble() * 100));
          expect(summary.min, isNegative);
          expect(summary.max, isPositive);
          expect(summary.mean, inInclusiveRange(-25, 25));

          expect(() => summary.simpleScore(-50), throwsRangeError);
          expect(() => summary.simpleScore(50), throwsRangeError);

          expect(summary.simpleScore(25), closeTo(0.75, 0.05));
          expect(summary.simpleScore(0), closeTo(0.5, 0.01));
          expect(summary.simpleScore(45), closeTo(0.95, 0.05));

          expect(summary.bezierScore(25), closeTo(0.87, 0.05));
          expect(summary.bezierScore(0), closeTo(0.68, 0.05));
          expect(summary.bezierScore(45), closeTo(0.975, 0.01));
        }
      });
    });
  });
  group('calculateBezierScore', () {
    var items = <List<num>>[
      [.75, .5, 0.87],
      [.5, .75, .5],
      [.2, .2, 0.591],
      [.5, .5, 0.6875],
      [0, .5, 0],
      [epsilon, .5, 0],
      [1 - epsilon, .75, 1],
      [1, .75, 1],
    ];

    for (var i in items) {
      var normValue = i[0];
      var normAvg = i[1];
      var expectedResult = i[2];
      test("$normValue, $normAvg", () {
        var result = calculateBezierScore(normValue, normAvg);

        expect(result, closeTo(expectedResult, 0.001));
      });
    }
  });

  group('cubeRoot', () {
    test('27', () {
      expect(cubeRoot(27), 3);
    });
    test('-27', () {
      expect(cubeRoot(-27), -3);
    });
  });

  group("foo", () {
    test('4, -8, 7', () {
      var thing = solveCubic(1, 2, 3, 4);
      expect(thing.single, closeTo(-1.65, .01));
    });
    test('6, 3, 4', () {
      var thing = solveCubic(1, 6, 3, 4);
      expect(thing.single, closeTo(-5.59, .01));
    });
  });
}
