import 'package:pana/src/tag/_flutter_plugins.dart';
import 'package:test/test.dart';

void main() {
  group('hasLegacyKotlinGroovy', () {
    test('matches legacy apply plugin: kotlin-android', () {
      expect(hasLegacyKotlinGroovy("apply plugin: 'kotlin-android'"), isTrue);
      expect(hasLegacyKotlinGroovy('apply plugin: "kotlin-android"'), isTrue);
      expect(
        hasLegacyKotlinGroovy("  apply   plugin:   'kotlin-android'  "),
        isTrue,
      );
    });

    test('matches legacy apply plugin: org.jetbrains.kotlin.android', () {
      expect(
        hasLegacyKotlinGroovy("apply plugin: 'org.jetbrains.kotlin.android'"),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy('apply plugin: "org.jetbrains.kotlin.android"'),
        isTrue,
      );
    });

    test('matches plugins block with id "kotlin-android"', () {
      expect(
        hasLegacyKotlinGroovy('''
          plugins {
              id 'kotlin-android'
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy('''
          plugins {
              id("kotlin-android")
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with id "org.jetbrains.kotlin.android"', () {
      expect(
        hasLegacyKotlinGroovy('''
          plugins {
              id 'org.jetbrains.kotlin.android'
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with alias', () {
      expect(
        hasLegacyKotlinGroovy('''
          plugins {
              alias(libs.plugins.kotlin.android)
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy('''
          plugins {
              alias libs.plugins.kotlin.android
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with id and version', () {
      expect(
        hasLegacyKotlinGroovy('''
          plugins {
              id 'kotlin-android' version '1.9.22'
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy('''
          plugins {
              id("org.jetbrains.kotlin.android") version "1.9.22"
          }
        '''),
        isTrue,
      );
    });

    test('matches pluginManager.apply', () {
      expect(
        hasLegacyKotlinGroovy("pluginManager.apply('kotlin-android')"),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy(
          'pluginManager.apply("org.jetbrains.kotlin.android")',
        ),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy(
          "pluginManager.apply 'org.jetbrains.kotlin.android'",
        ),
        isTrue,
      );
    });

    test('matches guarded KGP application', () {
      expect(
        hasLegacyKotlinGroovy('''
          if (agpMajor < 9) {
              apply plugin: 'kotlin-android'
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy(
          "if (agpMajor < 9) { apply plugin: 'kotlin-android' }",
        ),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy('''
          if (agpMajor < 9) {
              pluginManager.apply("org.jetbrains.kotlin.android")
          }
        '''),
        isTrue,
      );
    });

    test('matches kotlinOptions block and property access', () {
      expect(
        hasLegacyKotlinGroovy('''
          android {
              kotlinOptions {
                  jvmTarget = '1.8'
              }
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy('android.kotlinOptions { jvmTarget = "1.8" }'),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy('''
          android {
              kotlinOptions.jvmTarget = '1.8'
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinGroovy('android.kotlinOptions.jvmTarget = "1.8"'),
        isTrue,
      );
    });

    test('does not match commented out legacy KGP or kotlinOptions', () {
      expect(
        hasLegacyKotlinGroovy('''
          // apply plugin: 'kotlin-android'
        '''),
        isFalse,
      );
      expect(
        hasLegacyKotlinGroovy('''
          plugins {
              // id 'kotlin-android'
          }
        '''),
        isFalse,
      );
      expect(
        hasLegacyKotlinGroovy('''
          // android.kotlinOptions { jvmTarget = "1.8" }
        '''),
        isFalse,
      );
      expect(
        hasLegacyKotlinGroovy('''
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
        hasLegacyKotlinGroovy('''
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
        hasLegacyKotlinGroovy('''
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
        hasLegacyKotlinKotlin('''
          plugins {
              id("kotlin-android")
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with id("org.jetbrains.kotlin.android")', () {
      expect(
        hasLegacyKotlinKotlin('''
          plugins {
              id("org.jetbrains.kotlin.android")
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with id and version', () {
      expect(
        hasLegacyKotlinKotlin('''
          plugins {
              id("kotlin-android") version "1.9.22"
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinKotlin('''
          plugins {
              id("org.jetbrains.kotlin.android") version "1.9.22"
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with kotlin("android")', () {
      expect(
        hasLegacyKotlinKotlin('''
          plugins {
              kotlin("android")
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinKotlin('''
          plugins {
              kotlin("android") version "1.9.22"
          }
        '''),
        isTrue,
      );
    });

    test('matches plugins block with alias', () {
      expect(
        hasLegacyKotlinKotlin('''
          plugins {
              alias(libs.plugins.kotlin.android)
          }
        '''),
        isTrue,
      );
    });

    test('matches apply(plugin = ...)', () {
      expect(hasLegacyKotlinKotlin('apply(plugin = "kotlin-android")'), isTrue);
      expect(
        hasLegacyKotlinKotlin('apply(plugin = "org.jetbrains.kotlin.android")'),
        isTrue,
      );
    });

    test('matches pluginManager.apply(...)', () {
      expect(
        hasLegacyKotlinKotlin('pluginManager.apply("kotlin-android")'),
        isTrue,
      );
      expect(
        hasLegacyKotlinKotlin(
          'pluginManager.apply("org.jetbrains.kotlin.android")',
        ),
        isTrue,
      );
    });

    test('matches guarded KGP application', () {
      expect(
        hasLegacyKotlinKotlin('''
          if (agpMajor < 9) {
              apply(plugin = "org.jetbrains.kotlin.android")
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinKotlin('''
          if (agpMajor < 9) {
              pluginManager.apply("org.jetbrains.kotlin.android")
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinKotlin('''
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
        hasLegacyKotlinKotlin('''
          android {
              kotlinOptions {
                  jvmTarget = "1.8"
              }
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinKotlin('''
          android {
              kotlinOptions.jvmTarget = "1.8"
          }
        '''),
        isTrue,
      );
      expect(
        hasLegacyKotlinKotlin('android.kotlinOptions.jvmTarget = "17"'),
        isTrue,
      );
    });

    test('does not match Groovy-style id without parentheses', () {
      // Kotlin DSL requires parentheses for id(...)
      expect(
        hasLegacyKotlinKotlin('''
          plugins {
              id 'kotlin-android'
          }
        '''),
        isFalse,
      );
    });

    test('does not match commented out KGP or kotlinOptions', () {
      expect(
        hasLegacyKotlinKotlin('''
          plugins {
              // id("kotlin-android")
          }
        '''),
        isFalse,
      );
      expect(
        hasLegacyKotlinKotlin('''
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
