import 'package:pana/src/platform.dart';
import 'package:test/test.dart';

import 'pubspec_test.dart';

void main() {
  group('Platform', () {
    test('no libraries', () {
      var p = classifyLibPlatform([]);
      expect(p.worksEverywhere, isTrue);
      expect(p.restrictedTo, isNull);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
    });

    test('unknown library', () {
      var p = classifyLibPlatform(['package:_unknown/_unknown.dart']);
      expect(p.worksEverywhere, isTrue);
      expect(p.restrictedTo, isNull);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
    });

    test('dart:io', () {
      var p = classifyLibPlatform(['dart:io']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, ['flutter', 'server']);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
    });

    test('dart:html', () {
      var p = classifyLibPlatform(['dart:html']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, ['web']);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);

      p = classifyLibPlatform(['dart:svg']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, ['web']);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });

    test('dart:ui', () {
      var p = classifyLibPlatform(['dart:ui']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, ['flutter']);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isTrue);
    });

    test('dart:mirrors', () {
      var p = classifyLibPlatform(['dart:mirrors']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, ['server', 'web']);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isFalse);
    });

    test('http package: both html and io', () {
      var p = classifyLibPlatform(['dart:html', 'dart:io']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, ['web']);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });

    test('detect native', () {
      var p = classifyLibPlatform(['dart:io', 'dart-ext:some-extension']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, ['server']);
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isFalse);
    });
  });

  group('Conflicting Platform', () {
    test('dart:html + dart:ui', () {
      var p = classifyLibPlatform(['dart:html', 'dart:ui']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, isNull);
      expect(p.hasConflict, isTrue);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });

    test('dart:mirrors + dart:ui', () {
      var p = classifyLibPlatform(['dart:mirrors', 'dart:ui']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, isNull);
      expect(p.hasConflict, isTrue);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });

    test('native + dart:ui', () {
      var p = classifyLibPlatform(['dart:ui', 'dart-ext:some-extension']);
      expect(p.worksEverywhere, isFalse);
      expect(p.restrictedTo, isNull);
      expect(p.hasConflict, isTrue);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });
  });

  group('PkgPlatform', () {
    test('handles multiple libraries', () {
      var sum = classifyPkgPlatform(emptyPubspec, {
        'package:_example/a.dart': ['dart:html'],
        'package:_example/b.dart': ['dart:io'],
      });
      expect(sum.worksEverywhere, isFalse);
      expect(sum.restrictedTo, ['flutter', 'server', 'web']);
      expect(sum.reason, 'Multiple platform identified in libraries.');
    });

    test('detects flutter in pubspec', () {
      var sum = classifyPkgPlatform(flutterPluginPubspec, {});
      expect(sum.worksEverywhere, isFalse);
      expect(sum.restrictedTo, ['flutter']);
      expect(
          sum.reason, 'References Flutter, and has no conflicting libraries.');
    });

    test('detects flutter package in dependencies', () {
      var sum = classifyPkgPlatform(flutterDependencyPubspec, {});
      expect(sum.worksEverywhere, isFalse);
      expect(sum.restrictedTo, ['flutter']);
      expect(
          sum.reason, 'References Flutter, and has no conflicting libraries.');
    });

    test('detects flutter sdk in dependencies', () {
      var sum = classifyPkgPlatform(flutterSdkPubspec, {});
      expect(sum.worksEverywhere, isFalse);
      expect(sum.restrictedTo, ['flutter']);
      expect(
          sum.reason, 'References Flutter, and has no conflicting libraries.');
    });
  });

  group('Conflicting PkgPlatform', () {
    test('Flutter package with mirrors', () {
      var sum = classifyPkgPlatform(flutterPluginPubspec, {
        'package:_example/lib.dart': ['dart:mirrors'],
      });
      expect(sum.worksEverywhere, isFalse);
      expect(sum.restrictedTo, isNull);
      expect(sum.reason,
          'References Flutter, but has conflicting libraries: `package:_example/lib.dart`.');
    });
  });
}
