// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/session.dart';
import 'package:path/path.dart' as path;

import '_common.dart';
import '_graphs.dart';
import 'pana_tags.dart';

/// Returns the declared web plugin platform implementation library URIs
/// from `pubspec.yaml` (under `flutter.plugin.platforms.web.fileName`,
/// defaulting to `<package_name>_web.dart`), if the file exists.
List<Uri> findWebPluginLibraries(
  AnalysisSession session,
  PubspecCache pubspecCache,
  String packageName,
) {
  final pubspec = pubspecCache.pubspecOfPackage(packageName);
  if (!pubspec.hasFlutterPluginKey) return const <Uri>[];

  final plugin = pubspec.originalYaml['flutter'];
  if (plugin is! Map || plugin['plugin'] is! Map) return const <Uri>[];

  final platforms = plugin['plugin']['platforms'];
  if (platforms is! Map) return const <Uri>[];

  final webConfig = platforms['web'];
  if (webConfig is! Map) return const <Uri>[];

  var fileName = '${packageName}_web.dart';
  if (webConfig['fileName'] is String) {
    fileName = webConfig['fileName'] as String;
  }

  final fileUri = Uri.tryParse('package:$packageName/$fileName');
  if (fileUri == null) return const <Uri>[];
  final filePath = session.uriConverter.uriToPath(fileUri);
  if (filePath != null && File(filePath).existsSync()) {
    return <Uri>[fileUri];
  }
  return const <Uri>[];
}

/// Adds [PanaTags.isPlugin] if [packageName] declares `flutter.plugin` in its
/// `pubspec.yaml`.
void findFlutterPluginTags(
  PubspecCache pubspecCache,
  String packageName,
  List<String> tags,
  List<Explanation> explanations,
) {
  final pubspec = pubspecCache.pubspecOfPackage(packageName);
  if (pubspec.hasFlutterPluginKey) {
    tags.add(PanaTags.isPlugin);
  }
}

/// Tags whether an iOS/macOS Flutter plugin has migrated to Swift Package
/// Manager (swiftpm).
///
/// A plugin only needs to be swiftpm enabled if it has a native component,
/// detected via the `flutter.plugin.platforms.<os>.pluginClass` key in
/// `pubspec.yaml`.
///
/// A plugin can share code and package-manager manifest between iOS and macOS
/// by specifying `flutter.plugin.platforms.<os>.sharedDarwinSource`.
///
/// See https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors
void findSwiftPackageManagerPluginTags(
  PubspecCache pubspecCache,
  String packageName,
  String packageDir,
  List<String> tags,
  List<Explanation> explanations,
) {
  final mainPackagePubspec = pubspecCache.pubspecOfPackage(packageName);

  bool pathExists(dynamic m, List<String> keys) {
    dynamic current = m;
    for (final e in keys) {
      if (current is! Map) return false;
      if (!current.containsKey(e)) return false;
      current = current[e];
    }
    return true;
  }

  var isDarwinPlugin = false;
  var swiftPmSupport = true;

  for (final darwinOs in ['macos', 'ios']) {
    var defaultPackagePubspec = mainPackagePubspec;
    var defaultPackageDir = packageDir;
    final defaultPackageName = defaultPackagePubspec
        .originalYaml['flutter']?['plugin']?['platforms']?[darwinOs]?['default_package'];

    if (defaultPackageName is String) {
      defaultPackagePubspec = pubspecCache.pubspecOfPackage(defaultPackageName);
      defaultPackageDir = pubspecCache.packageDir(defaultPackageName);
    }

    if (pathExists(defaultPackagePubspec.originalYaml, [
      'flutter',
      'plugin',
      'platforms',
      darwinOs,
      'pluginClass',
    ])) {
      isDarwinPlugin = true;
      final osDir =
          defaultPackagePubspec
                  .originalYaml['flutter']?['plugin']?['platforms']?[darwinOs]?['sharedDarwinSource'] ==
              true
          ? 'darwin'
          : darwinOs;

      final packageSwiftFile = path.join(
        osDir,
        defaultPackageName is String ? defaultPackageName : packageName,
        'Package.swift',
      );
      if (!File(path.join(defaultPackageDir, packageSwiftFile)).existsSync()) {
        swiftPmSupport = false;
        final osName = {'macos': 'macOS', 'ios': 'iOS'}[darwinOs];
        explanations.add(
          Explanation(
            'Package does not support the Swift Package Manager on $osName',
            defaultPackageName is String
                ? 'The default package $defaultPackageName does not contain `$packageSwiftFile`.'
                : 'The package does not contain `$packageSwiftFile`.',
            tag: PanaTags.isSwiftPmPlugin,
          ),
        );
      }
    }
  }
  if (isDarwinPlugin) {
    if (swiftPmSupport) {
      tags.add(PanaTags.isSwiftPmPlugin);
    } else {
      tags.add(PanaTags.isDarwinLegacyNativeBuild);
    }
  }
}

/// Tags whether an Android Flutter plugin with Kotlin sources uses built-in
/// Kotlin or legacy Kotlin configuration.
void findKotlinPluginTags(
  PubspecCache pubspecCache,
  String packageName,
  String packageDir,
  List<String> tags,
  List<Explanation> explanations,
) {
  final mainPackagePubspec = pubspecCache.pubspecOfPackage(packageName);

  final flutter = mainPackagePubspec.originalYaml['flutter'];
  if (flutter is! Map) return;
  final plugin = flutter['plugin'];
  if (plugin is! Map) return;
  final isAndroidPlugin =
      plugin['androidPackage'] is String ||
      (plugin['platforms'] is Map && plugin['platforms']['android'] is Map);

  if (!isAndroidPlugin) return;

  var defaultPackagePubspec = mainPackagePubspec;
  var defaultPackageDir = packageDir;
  final defaultPackageName = defaultPackagePubspec
      .originalYaml['flutter']?['plugin']?['platforms']?['android']?['default_package'];

  if (defaultPackageName is String) {
    try {
      defaultPackagePubspec = pubspecCache.pubspecOfPackage(defaultPackageName);
      defaultPackageDir = pubspecCache.packageDir(defaultPackageName);
    } catch (e) {
      return;
    }
  }

  final androidDir = Directory(path.join(defaultPackageDir, 'android'));
  if (!androidDir.existsSync()) return;

  final buildGradle = File(path.join(androidDir.path, 'build.gradle'));
  final buildGradleKts = File(path.join(androidDir.path, 'build.gradle.kts'));
  final hasBuildGradle = buildGradle.existsSync();
  final hasBuildGradleKts = buildGradleKts.existsSync();
  if (!hasBuildGradle && !hasBuildGradleKts) return;

  final hasKotlinSources = androidDir
      .listSync(recursive: true, followLinks: false)
      .any((e) => e is File && e.path.endsWith('.kt'));
  if (!hasKotlinSources) return;

  var hasLegacyKotlin = false;
  String? buildGradlePath;

  if (hasBuildGradle) {
    final content = buildGradle.readAsStringSync();
    if (hasLegacyKotlinGroovy(content)) {
      hasLegacyKotlin = true;
      buildGradlePath = 'android/build.gradle';
    }
  } else if (hasBuildGradleKts) {
    final content = buildGradleKts.readAsStringSync();
    if (hasLegacyKotlinKotlin(content)) {
      hasLegacyKotlin = true;
      buildGradlePath = 'android/build.gradle.kts';
    }
  }

  if (hasLegacyKotlin) {
    explanations.add(
      Explanation(
        'Legacy Kotlin configuration detected in `$buildGradlePath`.',
        'This plugin applies the Kotlin Gradle Plugin (KGP) or uses the `android.kotlinOptions{}` block.',
        tag: PanaTags.isBuiltInKotlin,
      ),
    );
  } else {
    tags.add(PanaTags.isBuiltInKotlin);
  }
}

final _gradleCommentsOrStringsRegex = RegExp(
  r'"""[\s\S]*?"""|'
  r"'''[\s\S]*?'''|"
  r'"(?:\\.|[^"\\\n])*"|'
  r"'(?:\\.|[^'\\\n])*'|"
  r'/\*[\s\S]*?\*/|'
  r'//[^\n]*',
);

/// Strips `//` line comments and `/* ... */` block comments from Gradle build
/// file content while preserving string literals.
String _stripGradleComments(String content) {
  return content.replaceAllMapped(_gradleCommentsOrStringsRegex, (match) {
    final value = match.group(0)!;
    if (value.startsWith('//')) {
      return '';
    }
    if (value.startsWith('/*')) {
      return value.contains('\n') ? '\n' : ' ';
    }
    return value;
  });
}

const _quotedKgpIds =
    r'''(?:'(?:kotlin-android|org\.jetbrains\.kotlin\.android)'|"(?:kotlin-android|org\.jetbrains\.kotlin\.android)")''';

const _quotedAndroid = r'''(?:'android'|"android")''';

const _versionCatalogAliases = r'libs\.plugins\.(?:android|kotlin)\.android';

const _pluginsStart = r'\bplugins\s*\{';
const _insideBlockLazy = r'(?:\{[^{}]*\}|[^{}])*?(?:\{[^{}]*?)?';
const _startOfStatementInBlock = r'(?<=[\n{;])[ \t]*';
const _optionalVersion =
    r'(?:(?:[ \t]+version\b|[ \t]*\.version\s*\()[^\n;}]*)?';
const _endOfStatement = r'(?=[ \t]*(?:\n|$|\}|;))';

// Matches legacy `kotlinOptions { ... }` blocks and property assignments
// like `kotlinOptions.jvmTarget = ...` or `android.kotlinOptions.jvmTarget = ...`.
final _kotlinOptionsRegex = RegExp(
  r'\b(?:[a-zA-Z0-9_]+\.)*kotlinOptions(?:\s*\{|\.[a-zA-Z0-9_]+)',
  multiLine: true,
);

final _kgpRegexGroovy = () {
  final applyPluginPattern =
      r'\bapply(?:\s*\(\s*|\s+)plugin\s*[:=]\s*'
      '$_quotedKgpIds(?:\\s*\\))?';
  final pluginManagerApplyPattern =
      r'\b(?:pluginManager|plugins)\.apply(?:\s*\(\s*|\s+)'
      '$_quotedKgpIds(?:\\s*\\))?';
  final groovyPluginDeclaration =
      r'\b(?:'
      '(?:id|alias)(?:[ \\t]*\\(\\s*|[ \\t]+)'
      '(?:$_quotedKgpIds|$_versionCatalogAliases)(?:\\s*\\))?'
      '|'
      'kotlin(?:[ \\t]*\\(\\s*|[ \\t]+)$_quotedAndroid(?:\\s*\\))?'
      ')';
  final pluginsBlockPattern =
      '$_pluginsStart$_insideBlockLazy$_startOfStatementInBlock'
      '$groovyPluginDeclaration$_optionalVersion$_endOfStatement';
  return RegExp(
    '$applyPluginPattern|$pluginManagerApplyPattern|$pluginsBlockPattern',
    multiLine: true,
  );
}();

final _kgpRegexKotlin = () {
  final applyPluginPattern =
      r'\bapply\s*\(\s*plugin\s*=\s*'
      '$_quotedKgpIds\\s*\\)';
  final pluginManagerApplyPattern =
      r'\b(?:pluginManager|plugins)\.apply\s*\(\s*'
      '$_quotedKgpIds\\s*\\)';
  final kotlinPluginDeclaration =
      r'\b(?:'
      '(?:id|alias)[ \\t]*\\(\\s*'
      '(?:$_quotedKgpIds|$_versionCatalogAliases)\\s*\\)'
      '|'
      'kotlin[ \\t]*\\(\\s*$_quotedAndroid\\s*\\)'
      ')';
  final pluginsBlockPattern =
      '$_pluginsStart$_insideBlockLazy$_startOfStatementInBlock'
      '$kotlinPluginDeclaration$_optionalVersion$_endOfStatement';
  return RegExp(
    '$applyPluginPattern|$pluginManagerApplyPattern|$pluginsBlockPattern',
    multiLine: true,
  );
}();

/// Whether [content] (from an `android/build.gradle` Groovy file) applies the
/// legacy Kotlin Gradle Plugin or configures `kotlinOptions`.
bool hasLegacyKotlinGroovy(String content) {
  final stripped = _stripGradleComments(content);
  return _kgpRegexGroovy.hasMatch(stripped) ||
      _kotlinOptionsRegex.hasMatch(stripped);
}

/// Whether [content] (from an `android/build.gradle.kts` Kotlin script file)
/// applies the legacy Kotlin Gradle Plugin or configures `kotlinOptions`.
bool hasLegacyKotlinKotlin(String content) {
  final stripped = _stripGradleComments(content);
  return _kgpRegexKotlin.hasMatch(stripped) ||
      _kotlinOptionsRegex.hasMatch(stripped);
}
