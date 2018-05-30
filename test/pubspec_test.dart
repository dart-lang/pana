import 'package:pana/src/pubspec.dart';
import 'package:test/test.dart';

void main() {
  test('empty', () {
    expect(emptyPubspec.hasFlutterKey, isFalse);
    expect(emptyPubspec.hasFlutterPluginKey, isFalse);
    expect(emptyPubspec.dependsOnFlutterSdk, isFalse);
    expect(sdkOnlyEnvPubspec.dependsOnFlutterSdk, isFalse);
  });

  test('flutter', () {
    expect(flutterPluginPubspec.hasFlutterKey, isTrue);
    expect(flutterPluginPubspec.hasFlutterPluginKey, isTrue);
    expect(flutterPluginPubspec.dependsOnFlutterSdk, isFalse);
    expect(flutterSdkPubspec.hasFlutterKey, isFalse);
    expect(flutterSdkPubspec.hasFlutterPluginKey, isFalse);
    expect(flutterSdkPubspec.dependsOnFlutterSdk, isTrue);
    expect(flutterSdkDevPubspec.dependentSdks.toList(), ['flutter']);
    expect(flutterSdkDevPubspec.hasFlutterKey, isFalse);
    expect(flutterSdkDevPubspec.hasFlutterPluginKey, isFalse);
    expect(flutterSdkDevPubspec.dependsOnFlutterSdk, isTrue);
    expect(flutterSdkDevPubspec.dependentSdks.toList(), ['flutter']);
    expect(flutterInEnvPubspec.dependsOnFlutterSdk, isTrue);
  });

  test('unknown sdk', () {
    expect(unknownSdkPubspec.dependentSdks.toList(), ['unknown']);
  });
}

final Pubspec emptyPubspec = new Pubspec({
  'name': 'sample',
});

final Pubspec flutterPluginPubspec = new Pubspec({
  'name': 'sample',
  'flutter': {
    'plugin': {},
  },
});

final Pubspec flutterDependencyPubspec = new Pubspec({
  'name': 'sample',
  'dependencies': {
    'flutter': 'any',
  },
});

final Pubspec flutterSdkPubspec = new Pubspec({
  'name': 'sample',
  'dependencies': {
    'example': {
      'sdk': 'flutter',
    },
  },
});

final Pubspec flutterSdkDevPubspec = new Pubspec({
  'name': 'sample',
  'dev_dependencies': {
    'example': {
      'sdk': 'flutter',
    },
  },
});

final Pubspec unknownSdkPubspec = new Pubspec({
  'name': 'sample',
  'dependencies': {
    'example': {
      'sdk': 'unknown',
    },
  },
});

final Pubspec sdkOnlyEnvPubspec = new Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '^2.0.0',
  },
});

final Pubspec flutterInEnvPubspec = new Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '^2.0.0',
    'flutter': '^1.0.0',
  },
});
