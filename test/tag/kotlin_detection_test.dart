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

    test('matches plugins block with id and version', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              id 'kotlin-android' version '1.9.22'
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          plugins {
              id("org.jetbrains.kotlin.android") version "1.9.22"
          }
        '''),
        isTrue,
      );
    });

    test('matches pluginManager.apply', () {
      expect(
        Tagger.hasLegacyKotlinGroovy("pluginManager.apply('kotlin-android')"),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy(
          'pluginManager.apply("org.jetbrains.kotlin.android")',
        ),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy(
          "pluginManager.apply 'org.jetbrains.kotlin.android'",
        ),
        isTrue,
      );
    });

    test('matches guarded KGP application', () {
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          if (agpMajor < 9) {
              apply plugin: 'kotlin-android'
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy(
          "if (agpMajor < 9) { apply plugin: 'kotlin-android' }",
        ),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          if (agpMajor < 9) {
              pluginManager.apply("org.jetbrains.kotlin.android")
          }
        '''),
        isTrue,
      );
    });

    test('matches kotlinOptions block and property access', () {
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
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          android {
              kotlinOptions.jvmTarget = '1.8'
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinGroovy('android.kotlinOptions.jvmTarget = "1.8"'),
        isTrue,
      );
    });

    test('does not match commented out legacy KGP or kotlinOptions', () {
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
      expect(
        Tagger.hasLegacyKotlinGroovy('''
          /*
          apply plugin: 'kotlin-android'
          plugins {
              id 'org.jetbrains.kotlin.android'
          }
          android {
              kotlinOptions {
                  jvmTarget = '1.8'
              }
          }
          */
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

    test('matches plugins block with id and version', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              id("kotlin-android") version "1.9.22"
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              id("org.jetbrains.kotlin.android") version "1.9.22"
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with kotlin("android")', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              kotlin("android")
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              kotlin("android") version "1.9.22"
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

    test('matches apply(plugin = ...)', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('apply(plugin = "kotlin-android")'),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinKotlin(
          'apply(plugin = "org.jetbrains.kotlin.android")',
        ),
        isTrue,
      );
    });

    test('matches pluginManager.apply(...)', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('pluginManager.apply("kotlin-android")'),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinKotlin(
          'pluginManager.apply("org.jetbrains.kotlin.android")',
        ),
        isTrue,
      );
    });

    test('matches guarded KGP application', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          if (agpMajor < 9) {
              apply(plugin = "org.jetbrains.kotlin.android")
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          if (agpMajor < 9) {
              pluginManager.apply("org.jetbrains.kotlin.android")
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              id("com.android.library")
              if (agpMajor < 9) {
                  id("org.jetbrains.kotlin.android")
              }
          }
        '''),
        isTrue,
      );
    });

    test('matches kotlinOptions block and property access', () {
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
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          android {
              kotlinOptions.jvmTarget = "1.8"
          }
        '''),
        isTrue,
      );
      expect(
        Tagger.hasLegacyKotlinKotlin('android.kotlinOptions.jvmTarget = "17"'),
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

    test('does not match commented out KGP or kotlinOptions', () {
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          plugins {
              // id("kotlin-android")
          }
        '''),
        isFalse,
      );
      expect(
        Tagger.hasLegacyKotlinKotlin('''
          /*
          plugins {
              kotlin("android")
          }
          if (agpMajor < 9) {
              apply(plugin = "org.jetbrains.kotlin.android")
          }
          android {
              kotlinOptions.jvmTarget = "1.8"
          }
          */
        '''),
        isFalse,
      );
    });
  });
}
