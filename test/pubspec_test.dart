import 'package:pana/src/pubspec.dart';
import 'package:test/test.dart';

void main() {
  test('empty', () {
    expect(emptyPubspec.hasFlutterKey, isFalse);
    expect(emptyPubspec.hasFlutterPluginKey, isFalse);
    expect(emptyPubspec.dependsOnFlutterSdk, isFalse);
    expect(emptyPubspec.dependsOnAnyVersion, isFalse);
  });

  test('flutter', () {
    expect(flutterPluginPubspec.hasFlutterKey, isTrue);
    expect(flutterPluginPubspec.hasFlutterPluginKey, isTrue);
    expect(flutterPluginPubspec.dependsOnFlutterSdk, isFalse);
    expect(flutterPluginPubspec.dependsOnAnyVersion, isFalse);
    expect(flutterSdkPubspec.hasFlutterKey, isFalse);
    expect(flutterSdkPubspec.hasFlutterPluginKey, isFalse);
    expect(flutterSdkPubspec.dependsOnFlutterSdk, isTrue);
    expect(flutterSdkPubspec.dependsOnAnyVersion, isFalse);
    expect(flutterSdkDevPubspec.dependentSdks.toList(), ['flutter']);
    expect(flutterSdkDevPubspec.hasFlutterKey, isFalse);
    expect(flutterSdkDevPubspec.hasFlutterPluginKey, isFalse);
    expect(flutterSdkDevPubspec.dependsOnFlutterSdk, isTrue);
    expect(flutterSdkDevPubspec.dependsOnAnyVersion, isFalse);
    expect(flutterSdkDevPubspec.dependentSdks.toList(), ['flutter']);
  });

  test('unknown sdk', () {
    expect(unknownSdkPubspec.dependentSdks.toList(), ['unknown']);
  });

  test('detect any', () {
    expect(futureProofPubspec1.dependsOnAnyVersion, isTrue);
    expect(futureProofPubspec2.dependsOnAnyVersion, isTrue);
  });
}

final Pubspec emptyPubspec = new Pubspec({});

final Pubspec flutterPluginPubspec = new Pubspec({
  'flutter': {
    'plugin': {},
  },
});

final Pubspec flutterSdkPubspec = new Pubspec({
  'dependencies': {
    'example': {
      'sdk': 'flutter',
    },
  },
});

final Pubspec flutterSdkDevPubspec = new Pubspec({
  'dev_dependencies': {
    'example': {
      'sdk': 'flutter',
    },
  },
});

final Pubspec unknownSdkPubspec = new Pubspec({
  'dependencies': {
    'example': {
      'sdk': 'unknown',
    },
  },
});

final Pubspec futureProofPubspec1 = new Pubspec({
  'dependencies': {
    'http': 'any',
  },
});

final Pubspec futureProofPubspec2 = new Pubspec({
  'dependencies': {
    'http': {
      'version': 'any',
    },
  },
});
