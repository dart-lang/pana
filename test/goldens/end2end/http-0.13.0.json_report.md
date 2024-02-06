## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


### [*] 10/10 points: Use an OSI-approved license

Detected license: `BSD-3-Clause`.

## 10/10 Provide documentation

### [*] 10/10 points: Package has an example


## 20/20 Platform support

### [*] 20/20 points: Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **macOS**, **Linux**)

* ✓ Android
* ✓ iOS
* ✓ Windows
* ✓ Linux
* ✓ macOS
* ✓ Web

## 40/50 Pass static analysis

### [~] 40/50 points: code has no errors, warnings, lints, or formatting issues

<details>
<summary>
INFO: Dangling library doc comment.
</summary>

`lib/http.dart:5:1`

```
  ╷
5 │ /// A composable, [Future]-based library for making HTTP requests.
  │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/http.dart`
</details>

## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`http_parser`]|`^4.0.0`|4.0.2|4.0.2|
|[`meta`]|`^1.3.0`|1.11.0|1.11.0|
|[`path`]|`^1.8.0`|1.8.3|1.8.3|
|[`pedantic`]|`^1.10.0`|1.11.1|1.11.1|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`collection`]|-|1.18.0|1.18.0|
|[`source_span`]|-|1.10.0|1.10.0|
|[`string_scanner`]|-|1.2.0|1.2.0|
|[`term_glyph`]|-|1.2.1|1.2.1|
|[`typed_data`]|-|1.3.2|1.3.2|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`http_parser`]: https://pub.dev/packages/http_parser
[`meta`]: https://pub.dev/packages/meta
[`path`]: https://pub.dev/packages/path
[`pedantic`]: https://pub.dev/packages/pedantic
[`collection`]: https://pub.dev/packages/collection
[`source_span`]: https://pub.dev/packages/source_span
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data


### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs
