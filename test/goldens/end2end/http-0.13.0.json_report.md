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


## 10/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`http_parser`]|`^4.0.0`|4.0.0|4.0.0|
|[`meta`]|`^1.3.0`|1.3.0|1.3.0|
|[`path`]|`^1.8.0`|1.8.0|1.8.0|
|[`pedantic`]|`^1.10.0`|1.11.0|1.11.0|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`charcode`]|-|1.2.0|1.2.0|
|[`collection`]|-|1.15.0|1.15.0|
|[`source_span`]|-|1.8.1|1.8.1|
|[`string_scanner`]|-|1.1.0|1.1.0|
|[`term_glyph`]|-|1.2.0|1.2.0|
|[`typed_data`]|-|1.3.0|1.3.0|
</details>

To reproduce run `pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

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


### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.

## 0/0 Support sound null-safety

### [*] 0/0 points: Package and dependencies are fully migrated to null-safety, and will be awarded additional points in a planned future revision of the pub.dev points model.
