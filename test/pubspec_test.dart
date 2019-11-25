import 'package:pana/src/pubspec.dart';
import 'package:test/test.dart';

void main() {
  test('empty', () {
    expect(emptyPubspec.hasFlutterKey, isFalse);
    expect(emptyPubspec.hasFlutterPluginKey, isFalse);
    expect(emptyPubspec.dependsOnFlutterSdk, isFalse);
    expect(emptyPubspec.hasDartSdkConstraint, isFalse);
    expect(emptyPubspec.shouldWarnDart2Constraint, isTrue);
    expect(emptyPubspec.sdkConstraintStatus.enablesDart2Latest, isFalse);
    expect(emptyPubspec.sdkConstraintStatus.isDart2Compatible, isFalse);
  });

  test('dart1 vs dart2', () {
    expect(dart1OnlyPubspec.hasDartSdkConstraint, isTrue);
    expect(dart1OnlyPubspec.shouldWarnDart2Constraint, isTrue);
    expect(devSdkOnlyPubspec.hasDartSdkConstraint, isTrue);
    expect(devSdkOnlyPubspec.shouldWarnDart2Constraint, isTrue);
    expect(dart2Pubspec.hasDartSdkConstraint, isTrue);
    expect(dart2Pubspec.shouldWarnDart2Constraint, isFalse);

    expect(dart1OnlyPubspec.sdkConstraintStatus.enablesDart2Latest, isFalse);
    expect(dart1OnlyPubspec.sdkConstraintStatus.isDart2Compatible, isFalse);

    expect(devSdkOnlyPubspec.sdkConstraintStatus.enablesDart2Latest, isFalse);
    expect(devSdkOnlyPubspec.sdkConstraintStatus.isDart2Compatible, isFalse);

    expect(dart1andDart2Pubspec.sdkConstraintStatus.enablesDart2Latest, isTrue);
    expect(dart1andDart2Pubspec.sdkConstraintStatus.isDart2Compatible, isTrue);

    expect(dart2Pubspec.sdkConstraintStatus.enablesDart2Latest, isTrue);
    expect(dart2Pubspec.sdkConstraintStatus.isDart2Compatible, isTrue);

    expect(dart1andDart3Pubspec.sdkConstraintStatus.enablesDart2Latest, isTrue);
    expect(dart1andDart3Pubspec.sdkConstraintStatus.isDart2Compatible, isFalse);

    expect(unboundedSdkPubspec.sdkConstraintStatus.enablesDart2Latest, isTrue);
    expect(unboundedSdkPubspec.sdkConstraintStatus.isDart2Compatible, isFalse);
  });

  test('flutter', () {
    expect(dart2Pubspec.dependsOnFlutterSdk, isFalse);
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

  test('sdkTags', () {
    expect(emptyPubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
    expect(flutterPluginPubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
    expect(flutterDependencyPubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
    expect(flutterSdkPubspec.sdkTags(), {'sdk:flutter'});
    expect(flutterSdkDevPubspec.sdkTags(), {'sdk:flutter'});
    expect(unknownSdkPubspec.sdkTags(), isEmpty);
    expect(dart2Pubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
    expect(flutterInEnvPubspec.sdkTags(), {'sdk:flutter'});
    expect(dart1OnlyPubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
    expect(unboundedSdkPubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
    expect(dart1andDart2Pubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
    expect(devSdkOnlyPubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
    expect(dart1andDart3Pubspec.sdkTags(), {'sdk:dart', 'sdk:flutter'});
  });
}

final Pubspec emptyPubspec = Pubspec({
  'name': 'sample',
});

final Pubspec flutterPluginPubspec = Pubspec({
  'name': 'sample',
  'flutter': {
    'plugin': {},
  },
});

final Pubspec flutterDependencyPubspec = Pubspec({
  'name': 'sample',
  'dependencies': {
    'flutter': 'any',
  },
});

final Pubspec flutterSdkPubspec = Pubspec({
  'name': 'sample',
  'dependencies': {
    'example': {
      'sdk': 'flutter',
    },
  },
});

final Pubspec flutterSdkDevPubspec = Pubspec({
  'name': 'sample',
  'dev_dependencies': {
    'example': {
      'sdk': 'flutter',
    },
  },
});

final Pubspec unknownSdkPubspec = Pubspec({
  'name': 'sample',
  'dependencies': {
    'example': {
      'sdk': 'unknown',
    },
  },
});

final Pubspec dart2Pubspec = Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '^2.0.0',
  },
});

final Pubspec flutterInEnvPubspec = Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '^2.0.0',
    'flutter': '^1.0.0',
  },
});

final Pubspec dart1OnlyPubspec = Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '<1.25.0',
  },
});

final unboundedSdkPubspec = Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '>1.2.0',
  },
});

final dart1andDart2Pubspec = Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '>1.2.0 <3.0.0',
  },
});

final dart1andDart3Pubspec = Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '>1.2.0 <4.0.0',
  },
});

final Pubspec devSdkOnlyPubspec = Pubspec({
  'name': 'sample',
  'environment': {
    'sdk': '<2.0.0',
  },
});
