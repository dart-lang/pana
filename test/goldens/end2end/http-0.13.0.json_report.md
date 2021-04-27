## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/main.dart`

## 20/20 Support multiple platforms

### [*] 20/20 points: Supports 2 of 2 possible platforms (**native**, **js**)


## 30/30 Pass static analysis

### [*] 30/30 points: code has no errors, warnings, lints, or formatting issues


## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`http_parser`]|`^{{version}}`|{{version}}|{{version}}|
|[`meta`]|`^{{version}}`|{{version}}|{{version}}|
|[`path`]|`^{{version}}`|{{version}}|{{version}}|
|[`pedantic`]|`^{{version}}`|{{version}}|{{version}}|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`charcode`]|-|{{version}}|{{version}}|
|[`collection`]|-|{{version}}|{{version}}|
|[`source_span`]|-|{{version}}|{{version}}|
|[`string_scanner`]|-|{{version}}|{{version}}|
|[`term_glyph`]|-|{{version}}|{{version}}|
|[`typed_data`]|-|{{version}}|{{version}}|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`http_parser`]: https://pub.dev/packages/http_parser
[`meta`]: https://pub.dev/packages/meta
[`path`]: https://pub.dev/packages/path
[`pedantic`]: https://pub.dev/packages/pedantic
[`charcode`]: https://pub.dev/packages/charcode
[`collection`]: https://pub.dev/packages/collection
[`source_span`]: https://pub.dev/packages/source_span
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data


### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
