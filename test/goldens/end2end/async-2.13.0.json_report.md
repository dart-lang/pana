## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `BSD-3-Clause`.


## 0/20 Provide documentation

### [x] 0/10 points: 20% or more of the public API has dartdoc comments

Could not run `dartdoc`: Exception: 1
<***>
Resolving dependencies...
Downloading packages...
+ _fe_analyzer_shared 95.0.0
+ analyzer 10.1.0
+ args 2.7.0
+ async 2.13.0
+ collection 1.19.1
+ convert 3.1.2
+ crypto 3.0.7
+ csslib 1.0.2
+ dartdoc 9.0.2
+ file 7.0.1
+ glob 2.1.3
+ html 0.15.6
+ logging 1.3.0
+ markdown 7.3.0
+ meta 1.18.1
+ package_config 2.2.0
+ path 1.9.1
+ pub_semver 2.2.0
+ source_span 1.10.2
+ string_scanner 1.4.1
+ term_glyph 1.2.2
+ typed_data 1.4.0
+ watcher 1.2.1
+ yaml 3.1.3
Building package executables...
<***>
Failed to build dartdoc:dartdoc:
{{temp-dir}}/pub-cache/hosted/pub.dev/dartdoc-9.0.2/lib/src/model/package_builder.dart:120:9: Error: Undefined name 'EmbedderYamlLocator'.
        EmbedderYamlLocator.forLibFolder(skyEngineLibFolder).embedderYamls,
        ^^^^^^^^^^^^^^^^^^^
{{temp-dir}}/pub-cache/hosted/pub.dev/dartdoc-9.0.2/lib/src/model/package_builder.dart:119:23: Error: Couldn't find constructor 'EmbedderSdk'.
    var embedderSdk = EmbedderSdk(resourceProvider,
                      ^^^^^^^^^^^

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>


## 20/20 Platform support

### [*] 20/20 points: Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **macOS**, **Linux**)

* ✓ Android

* ✓ iOS

* ✓ Windows

* ✓ Linux

* ✓ macOS

* ✓ Web


**WASM-ready:** This package is compatible with runtime `wasm`. See https://dart.dev/web/wasm for details.


## 50/50 Pass static analysis

### [*] 50/50 points: code has no errors, warnings, lints, or formatting issues


## 40/40 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|Notes|
|:-|:-|:-|:-|:-|
|[`collection`]|`^1.15.0`|1.19.1|1.19.1||
|[`meta`]|`^1.3.0`|1.17.0|1.17.0||

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`collection`]: https://pub.dev/packages/collection
[`meta`]: https://pub.dev/packages/meta

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.
