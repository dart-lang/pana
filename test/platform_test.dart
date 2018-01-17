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
          'flutter: allowed, server: allowed, web: allowed');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
    });

    test('unknown library', () {
      var p = classifyLibPlatform(['package:_unknown/_unknown.dart']);
      expect(p.worksEverywhere, isTrue);
      expect(p.components, []);
      expect(p.longPlatformDebug,
          'flutter: allowed, server: allowed, web: allowed');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
    });

    test('dart:io', () {
      var p = classifyLibPlatform(['dart:io']);
      expect(p.worksEverywhere, isTrue);
      expect(p.components, ['io']);
      expect(
          p.longPlatformDebug, 'flutter: allowed, server: used, web: allowed');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
    });

    test('dart:html', () {
      var p = classifyLibPlatform(['dart:html']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['html']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, server: forbidden, web: used');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);

      p = classifyLibPlatform(['dart:svg']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['html']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, server: forbidden, web: used');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });

    test('dart:ui', () {
      var p = classifyLibPlatform(['dart:ui']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['flutter']);
      expect(p.longPlatformDebug,
          'flutter: used, server: forbidden, web: forbidden');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isTrue);
    });

    test('dart:mirrors', () {
      var p = classifyLibPlatform(['dart:mirrors']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['mirrors']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, server: allowed, web: allowed');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isFalse);
    });

    test('http package: both html and io', () {
      var p = classifyLibPlatform(['dart:html', 'dart:io']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['html', 'io']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, server: conflict, web: used');
      expect(p.hasConflict, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });

    test('detect native', () {
      var p = classifyLibPlatform(['dart:io', 'dart-ext:some-extension']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['io', 'nativewrappers']);
      expect(p.longPlatformDebug,
          'flutter: forbidden, server: used, web: forbidden');
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
      expect(p.components, ['flutter', 'html']);
      expect(p.longPlatformDebug,
          'flutter: conflict, server: forbidden, web: conflict');
      expect(p.hasConflict, isTrue);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });

    test('dart:mirrors + dart:ui', () {
      var p = classifyLibPlatform(['dart:mirrors', 'dart:ui']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['flutter', 'mirrors']);
      expect(p.longPlatformDebug,
          'flutter: conflict, server: forbidden, web: forbidden');
      expect(p.hasConflict, isTrue);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
    });

    test('native + dart:ui', () {
      var p = classifyLibPlatform(['dart:ui', 'dart-ext:some-extension']);
      expect(p.worksEverywhere, isFalse);
      expect(p.components, ['flutter', 'nativewrappers']);
      expect(p.longPlatformDebug,
          'flutter: conflict, server: conflict, web: forbidden');
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
      expect(sum.components, ['html', 'io']);
      expect(sum.longPlatformDebug,
          'flutter: forbidden, server: conflict, web: used');
      expect(sum.reason, 'Multiple platform identified in libraries.');
    });

    test('detects flutter in pubspec', () {
      var sum = classifyPkgPlatform(flutterPluginPubspec, {});
      expect(sum.worksEverywhere, isFalse);
      expect(sum.components, ['flutter']);
      expect(sum.longPlatformDebug,
          'flutter: used, server: forbidden, web: forbidden');
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
          'flutter: used, server: forbidden, web: forbidden');
      expect(
          sum.reason, 'References Flutter, and has no conflicting libraries.');
    });

    test('detects flutter sdk in dependencies', () {
      var sum = classifyPkgPlatform(flutterSdkPubspec, {});
      expect(sum.worksEverywhere, isFalse);
      expect(sum.components, ['flutter']);
      expect(sum.longPlatformDebug,
          'flutter: used, server: forbidden, web: forbidden');
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
      expect(sum.worksAnywhere, isFalse);
      expect(sum.components, null);
      expect(sum.reason,
          'References Flutter, but has conflicting libraries: `package:_example/lib.dart`.');
    });
  });
}
