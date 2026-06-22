import 'package:pana/src/tag/tagger.dart';
import 'package:test/test.dart';

void main() {
  group('hasLegacyKotlinGroovy', () {
    test('matches legacy apply plugin: kotlin-android', () {
      expect(
        Tagger.hasLegacyKotlinGroovy("apply plugin: 'kotlin-android'"),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy('apply plugin: "kotlin-android"'),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy("  apply   plugin:   'kotlin-android'  "),
        isTrue,
      );
    });

    test('matches legacy apply plugin: org.jetbrains.kotlin.android', () {
      expect(
        Tagger.hasLegacyKotlinGroovy(
          "apply plugin: 'org.jetbrains.kotlin.android'",
        ),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy(
          'apply plugin: "org.jetbrains.kotlin.android"',
        ),
        isTrue,
      );
    });

    test('matches plugins block with id "kotlin-android"', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              id 'kotlin-android'
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              id("kotlin-android")
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with id "org.jetbrains.kotlin.android"', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              id 'org.jetbrains.kotlin.android'
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with alias', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              alias(libs.plugins.kotlin.android)
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              alias libs.plugins.kotlin.android
          }
        '''),
        isTrue,
      );
    });

    test('matches kotlinOptions block', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          android {
              kotlinOptions {
                  jvmTarget = '1.8'
              }
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy(
          'android.kotlinOptions { jvmTarget = "1.8" }',
        ),
        isTrue,
      );
    });

    test('does not match commented out legacy KGP', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          // apply plugin: 'kotlin-android'
        '''),
        isFalse,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              // id 'kotlin-android'
          }
        '''),
        isFalse,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          // android.kotlinOptions { jvmTarget = "1.8" }
        '''),
        isFalse,
      );
    });

    test('does not match modern kotlin compilerOptions', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          kotlin {
              compilerOptions {
                  jvmTarget.set(JvmTarget.JVM_1_8)
              }
          }
        '''),
        isFalse,
      );
    });

    test('does not match unrelated plugins', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              id 'com.android.library'
          }
        '''),
        isFalse,
      );
    });
  });

  group('hasLegacyKotlinKotlin', () {
    test('matches plugins block with id("kotlin-android")', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              id("kotlin-android")
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with id("org.jetbrains.kotlin.android")', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              id("org.jetbrains.kotlin.android")
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with alias', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              alias(libs.plugins.kotlin.android)
          }
        '''),
        isTrue,
      );
    });

    test('matches kotlinOptions block', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          android {
              kotlinOptions {
                  jvmTarget = "1.8"
              }
          }
        '''),
        isTrue,
      );
    });

    test('does not match Groovy-style id without parentheses', () {
      // Kotlin DSL requires parentheses for id(...)
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              id 'kotlin-android'
          }
        '''),
        isFalse,
      );
    });

    test('does not match commented out KGP', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              // id("kotlin-android")
          }
        '''),
        isFalse,
      );
    });
  });
}
