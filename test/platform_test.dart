import 'package:pana/src/platform.dart';
import 'package:test/test.dart';

import 'pubspec_test.dart';

void main() {
  group('Platform', () {
    test('no libraries', () {
      var p = classifyLibPlatform([]);
      expect(p.worksEverywhere, isTrue);
      expect(p.components, []);
      expect(p.longPlatformDebug,
          'flutter: allowed, web: allowed, other: allowed');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnFlutter, isTrue);
      expect(p.worksOnOther, isTrue);
    });

    test('unknown library', () {
      var p = classifyLibPlatform(['package:_unknown/_unknown.dart']);
      expect(p.worksEverywhere, isTrue);
      expect(p.components, []);
      expect(p.longPlatformDebug,
          'flutter: allowed, web: allowed, other: allowed');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnFlutter, isTrue);
      expect(p.worksOnOther, isTrue);
    });

    test('dart:io', () {
      var p = classifyLibPlatform(['dart:io']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['io']);
      expect(
          p.longPlatformDebug, 'flutter: allowed, web: forbidden, other: used');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnFlutter, isTrue);
      expect(p.worksOnOther, isTrue);
    });

    test('dart:isolate', () {
      var p = classifyLibPlatform(['dart:isolate']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['isolate']);
      expect(
          p.longPlatformDebug, 'flutter: allowed, web: forbidden, other: used');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnFlutter, isTrue);
      expect(p.worksOnOther, isTrue);
    });

    test('dart:html', () {
      var p = classifyLibPlatform(['dart:html']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['html']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, web: used, other: forbidden');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnFlutter, isFalse);
      expect(p.worksOnOther, isFalse);

      p = classifyLibPlatform(['dart:svg']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['html']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, web: used, other: forbidden');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnFlutter, isFalse);
      expect(p.worksOnOther, isFalse);
    });

    test('dart:ui', () {
      var p = classifyLibPlatform(['dart:ui']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['flutter']);
      expect(p.longPlatformDebug,
          'flutter: used, web: forbidden, other: forbidden');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnFlutter, isTrue);
      expect(p.worksOnOther, isFalse);
    });

    test('dart:mirrors', () {
      var p = classifyLibPlatform(['dart:mirrors']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['mirrors']);
      expect(
          p.longPlatformDebug, 'flutter: forbidden, web: allowed, other: used');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnFlutter, isFalse);
      expect(p.worksOnOther, isTrue);
    });

    test('http package: both html and io', () {
      var p = classifyLibPlatform(['dart:html', 'dart:io']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['html', 'io']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, web: used, other: conflict');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnFlutter, isFalse);
      expect(p.worksOnOther, isFalse);
    });

    test('detect native', () {
      var p = classifyLibPlatform(['dart:io', 'dart-ext:some-extension']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['io', 'nativewrappers']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, web: forbidden, other: used');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.worksOnOther, isTrue);
    });
  });

  group('Conflicting Platform', () {
    test('dart:html + dart:ui', () {
      var p = classifyLibPlatform(['dart:html', 'dart:ui']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['flutter', 'html']);
      expect(p.longPlatformDebug,
          'flutter: conflict, web: conflict, other: forbidden');
      expect(p.hasConflict, isTrue);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.worksOnOther, isFalse);
    });

    test('dart:mirrors + dart:ui', () {
      var p = classifyLibPlatform(['dart:mirrors', 'dart:ui']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['flutter', 'mirrors']);
      expect(p.longPlatformDebug,
          'flutter: conflict, web: forbidden, other: conflict');
      expect(p.hasConflict, isTrue);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.worksOnOther, isFalse);
    });

    test('native + dart:ui', () {
      var p = classifyLibPlatform(['dart:ui', 'dart-ext:some-extension']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['flutter', 'nativewrappers']);
      expect(p.longPlatformDebug,
          'flutter: conflict, web: forbidden, other: conflict');
      expect(p.hasConflict, isTrue);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.worksOnOther, isFalse);
    });
  });

  group('PkgPlatform', () {
    test('handles multiple libraries', () {
      var sum = classifyPkgPlatform(emptyPubspec, {
        'package:_example/a.dart': ['dart:html'],
        'package:_example/b.dart': ['dart:io'],
      });
      expect(sum.worksEverywhere, isFalse);
      expect(sum.components, ['html', 'io']);
      expect(sum.longPlatformDebug,
          'flutter: forbidden, web: used, other: conflict');
      expect(sum.reason,
          'Platform components identified in package: `html`, `io`.');
    });

    test('detects flutter in pubspec', () {
      var sum = classifyPkgPlatform(flutterPluginPubspec, {});
      expect(sum.worksEverywhere, isFalse);
      expect(sum.components, ['flutter']);
      expect(sum.longPlatformDebug,
          'flutter: used, web: forbidden, other: forbidden');
      expect(
          sum.reason, 'References Flutter, and has no conflicting libraries.');
    });

    test('detects flutter package in dependencies', () {
      var sum = classifyPkgPlatform(emptyPubspec, {
        'package:_example/a.dart': ['dart:ui'],
      });
      expect(sum.worksEverywhere, isFalse);
      expect(sum.components, ['flutter']);
      expect(sum.longPlatformDebug,
          'flutter: used, web: forbidden, other: forbidden');
      expect(
          sum.reason, 'References Flutter, and has no conflicting libraries.');
    });

    test('detects flutter sdk in dependencies', () {
      var sum = classifyPkgPlatform(flutterSdkPubspec, {});
      expect(sum.worksEverywhere, isFalse);
      expect(sum.components, ['flutter']);
      expect(sum.longPlatformDebug,
          'flutter: used, web: forbidden, other: forbidden');
      expect(
          sum.reason, 'References Flutter, and has no conflicting libraries.');
    });
  });

  group('Conflicting PkgPlatform', () {
    test('Web package with isolate', () {
      var sum = classifyPkgPlatform(emptyPubspec, {
        'package:_example/lib.dart': ['dart:html', 'dart:isolate'],
      });
      expect(sum.worksEverywhere, isFalse);
      expect(sum.worksAnywhere, isFalse);
      expect(sum.components, null);
      expect(sum.reason,
          'Conflicting libraries: `package:_example/lib.dart` (components: `html`, `isolate`).');
    });

    test('Flutter package with mirrors', () {
      var sum = classifyPkgPlatform(flutterPluginPubspec, {
        'package:_example/lib.dart': ['dart:mirrors'],
      });
      expect(sum.worksEverywhere, isFalse);
      expect(sum.worksAnywhere, isFalse);
      expect(sum.components, null);
      expect(sum.reason,
          'References Flutter, but has conflicting libraries: `package:_example/lib.dart` (components: `mirrors`).');
    });
  });
}
