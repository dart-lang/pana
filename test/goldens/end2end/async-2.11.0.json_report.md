## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


### [*] 10/10 points: Use an OSI-approved license

Detected license: `BSD-3-Clause`.

## 10/20 Provide documentation

### [*] 10/10 points: 20% or more of the public API has dartdoc comments

246 out of 246 API elements (100.0 %) have documentation comments.

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

## 50/50 Pass static analysis

### [*] 50/50 points: code has no errors, warnings, lints, or formatting issues


## 40/40 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`collection`]|`^1.15.0`|1.18.0|1.18.0|
|[`meta`]|`^1.1.7`|1.11.0|1.11.0|

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`collection`]: https://pub.dev/packages/collection
[`meta`]: https://pub.dev/packages/meta


### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


### [*] 20/20 points: Dependency constraint lower bounds are not breaking

`pub downgrade` does not expose any static analysis error.