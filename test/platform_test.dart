import 'package:pana/src/platform.dart';
import 'package:test/test.dart';

import 'pubspec_test.dart';

void main() {
  group('Platform', () {
    test('no libraries', () {
      var p = classifyPlatform([]);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isTrue);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
      expect(p.description, 'everywhere');
    });

    test('unknown library', () {
      var p = classifyPlatform(['package:_unknown/_unknown.dart']);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isTrue);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
      expect(p.description, 'everywhere');
    });

    test('dart:io', () {
      var p = classifyPlatform(['dart:io']);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isTrue);
      expect(p.description, 'flutter, server');
    });

    test('dart:html', () {
      var p = classifyPlatform(['dart:html']);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.description, 'web');

      p = classifyPlatform(['dart:svg']);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.description, 'web');
    });

    test('dart:ui', () {
      var p = classifyPlatform(['dart:ui']);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isTrue);
      expect(p.description, 'flutter');
    });

    test('dart:mirrors', () {
      var p = classifyPlatform(['dart:mirrors']);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isFalse);
      expect(p.description, 'server, web');
    });

    test('http package: both html and io', () {
      var p = classifyPlatform(['dart:html', 'dart:io']);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isTrue);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.description, 'web');
    });

    test('detect native', () {
      var p = classifyPlatform(['dart:io', 'dart-ext:some-extension']);
      expect(p.hasConflict, isFalse);
      expect(p.worksAnywhere, isTrue);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isTrue);
      expect(p.worksOnFlutter, isFalse);
      expect(p.uses, [PlatformFlags.dartExtension, 'dart:io']);
      expect(p.description, 'server');
    });
  });

  group('Conflicting Platform', () {
    test('dart:html + dart:ui', () {
      var p = classifyPlatform(['dart:html', 'dart:ui']);
      expect(p.hasConflict, isTrue);
      expect(p.worksAnywhere, isFalse);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.description, 'conflict');
    });

    test('dart:mirrors + dart:ui', () {
      var p = classifyPlatform(['dart:mirrors', 'dart:ui']);
      expect(p.hasConflict, isTrue);
      expect(p.worksAnywhere, isFalse);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.description, 'conflict');
    });

    test('native + dart:ui', () {
      var p = classifyPlatform(['dart:ui', 'dart-ext:some-extension']);
      expect(p.hasConflict, isTrue);
      expect(p.worksAnywhere, isFalse);
      expect(p.worksEverywhere, isFalse);
      expect(p.worksOnWeb, isFalse);
      expect(p.worksOnServer, isFalse);
      expect(p.worksOnFlutter, isFalse);
      expect(p.uses, [PlatformFlags.dartExtension, 'dart:ui']);
      expect(p.description, 'conflict');
    });
  });

  group('PlatformSummary', () {
    test('handles multiple libraries', () {
      var sum = classifyPlatforms(emptyPubspec, {
        'package:_example/a.dart': ['dart:html'],
        'package:_example/b.dart': ['dart:io'],
      });
      expect(sum.hasConflict, isFalse);
      expect(sum.package.worksEverywhere, isTrue);
      expect(sum.libraries.length, 2);
      expect(sum.package.description, 'everywhere');

      var pa = sum.libraries['package:_example/a.dart'];
      expect(pa.worksOnWeb, isTrue);
      expect(pa.worksOnServer, isFalse);
      expect(pa.description, 'web');

      var pb = sum.libraries['package:_example/b.dart'];
      expect(pb.worksOnWeb, isFalse);
      expect(pb.worksOnServer, isTrue);
      expect(pb.description, 'flutter, server');
    });

    test('detects flutter in pubspec', () {
      var sum = classifyPlatforms(flutterPluginPubspec, {});
      expect(sum.hasConflict, isFalse);
      expect(sum.package.worksOnFlutter, isTrue);
      expect(sum.package.worksOnServer, isFalse);
      expect(sum.package.worksOnWeb, isFalse);
      expect(sum.package.description, 'flutter');
    });

    test('detects flutter in dependencies', () {
      var sum = classifyPlatforms(flutterSdkPubspec, {});
      expect(sum.hasConflict, isFalse);
      expect(sum.package.worksOnFlutter, isTrue);
      expect(sum.package.worksOnServer, isFalse);
      expect(sum.package.worksOnWeb, isFalse);
      expect(sum.package.description, 'flutter');
    });
  });

  group('Conflicting PlatformSummary', () {
    test('Flutter package with mirrors', () {
      var sum = classifyPlatforms(flutterPluginPubspec, {
        'package:_example/lib.dart': ['dart:mirrors'],
      });
      expect(sum.hasConflict, isTrue);
      expect(sum.package.description, 'flutter');
    });
  });
}
