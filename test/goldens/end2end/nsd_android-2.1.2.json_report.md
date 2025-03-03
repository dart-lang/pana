## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.


## 0/10 Provide documentation

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>


## 20/20 Platform support

### [*] 20/20 points: Supports 1 of 6 possible platforms (iOS, **Android**, Web, Windows, macOS, Linux)

* ✓ Android


These platforms are not supported:

<details>
<summary>
Package does not support platform `iOS`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>

<details>
<summary>
Package does not support platform `Windows`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>

<details>
<summary>
Package does not support platform `Linux`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>

<details>
<summary>
Package does not support platform `macOS`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>

<details>
<summary>
Package does not support platform `Web`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>

### [*] 0/0 points: WASM compatibility

This package is compatible with runtime `wasm`, and will be rewarded additional points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## 50/50 Pass static analysis

### [*] 50/50 points: code has no errors, warnings, lints, or formatting issues


## 40/40 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`flutter`]|`flutter`|0.0.0|0.0.0|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`characters`]|-|1.4.0|1.4.0|
|[`collection`]|-|1.19.1|1.19.1|
|[`material_color_utilities`]|-|0.11.1|0.12.0|
|[`meta`]|-|1.16.0|1.16.0|
|[`sky_engine`]|-|0.0.0|0.0.0|
|[`vector_math`]|-|2.1.4|2.1.4|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`flutter`]: https://pub.dev/packages/flutter
[`characters`]: https://pub.dev/packages/characters
[`collection`]: https://pub.dev/packages/collection
[`material_color_utilities`]: https://pub.dev/packages/material_color_utilities
[`meta`]: https://pub.dev/packages/meta
[`sky_engine`]: https://pub.dev/packages/sky_engine
[`vector_math`]: https://pub.dev/packages/vector_math

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.
