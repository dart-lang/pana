## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example


## 20/20 Platform support

### [*] 20/20 points: Supports 1 of 6 possible platforms (iOS, **Android**, Web, Windows, MacOS, Linux)

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

## 30/30 Pass static analysis

### [*] 30/30 points: code has no errors, warnings, lints, or formatting issues


## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`flutter`]|`flutter`|0.0.0|0.0.0|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`characters`]|-|1.2.0|1.2.0|
|[`collection`]|-|1.15.0|1.16.0|
|[`material_color_utilities`]|-|0.1.3|0.1.4|
|[`meta`]|-|1.7.0|1.7.0|
|[`sky_engine`]|-|0.0.99|0.0.99|
|[`typed_data`]|-|1.3.0|1.3.0|
|[`vector_math`]|-|2.1.1|2.1.2|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`flutter`]: https://pub.dev/packages/flutter
[`characters`]: https://pub.dev/packages/characters
[`collection`]: https://pub.dev/packages/collection
[`material_color_utilities`]: https://pub.dev/packages/material_color_utilities
[`meta`]: https://pub.dev/packages/meta
[`sky_engine`]: https://pub.dev/packages/sky_engine
[`typed_data`]: https://pub.dev/packages/typed_data
[`vector_math`]: https://pub.dev/packages/vector_math


### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
