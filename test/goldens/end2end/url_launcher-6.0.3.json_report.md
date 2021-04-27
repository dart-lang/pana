## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/lib/main.dart`

## 20/20 Support multiple platforms

### [*] 20/20 points: Supports 3 of 3 possible platforms (**iOS**, **Android**, **Web**)


## 30/30 Pass static analysis

### [*] 30/30 points: code has no errors, warnings, lints, or formatting issues


## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`flutter`]|`flutter`|{{version}}|{{version}}|
|[`url_launcher_linux`]|`^{{version}}`|{{version}}|{{version}}|
|[`url_launcher_macos`]|`^{{version}}`|{{version}}|{{version}}|
|[`url_launcher_platform_interface`]|`^{{version}}`|{{version}}|{{version}}|
|[`url_launcher_web`]|`^{{version}}`|{{version}}|{{version}}|
|[`url_launcher_windows`]|`^{{version}}`|{{version}}|{{version}}|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`characters`]|-|{{version}}|{{version}}|
|[`collection`]|-|{{version}}|{{version}}|
|[`flutter_web_plugins`]|-|{{version}}|{{version}}|
|[`js`]|-|{{version}}|{{version}}|
|[`meta`]|-|{{version}}|{{version}}|
|[`sky_engine`]|-|{{version}}|{{version}}|
|[`typed_data`]|-|{{version}}|{{version}}|
|[`vector_math`]|-|{{version}}|{{version}}|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`flutter`]: https://pub.dev/packages/flutter
[`url_launcher_linux`]: https://pub.dev/packages/url_launcher_linux
[`url_launcher_macos`]: https://pub.dev/packages/url_launcher_macos
[`url_launcher_platform_interface`]: https://pub.dev/packages/url_launcher_platform_interface
[`url_launcher_web`]: https://pub.dev/packages/url_launcher_web
[`url_launcher_windows`]: https://pub.dev/packages/url_launcher_windows
[`characters`]: https://pub.dev/packages/characters
[`collection`]: https://pub.dev/packages/collection
[`flutter_web_plugins`]: https://pub.dev/packages/flutter_web_plugins
[`js`]: https://pub.dev/packages/js
[`meta`]: https://pub.dev/packages/meta
[`sky_engine`]: https://pub.dev/packages/sky_engine
[`typed_data`]: https://pub.dev/packages/typed_data
[`vector_math`]: https://pub.dev/packages/vector_math


### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
