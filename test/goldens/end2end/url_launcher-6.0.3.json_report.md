## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/lib/main.dart`

## 20/20 Platform Support

### [*] 20/20 points: Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **MacOS**, **Linux**)

* ✓ Android
* ✓ iOS
* ✓ Windows
* ✓ Linux
* ✓ MacOS
* ✓ Web

## 30/30 Pass static analysis

### [*] 30/30 points: code has no errors, warnings, lints, or formatting issues


## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`flutter`]|`flutter`|0.0.0|0.0.0|
|[`url_launcher_linux`]|`^2.0.0`|2.0.3|2.0.3|
|[`url_launcher_macos`]|`^2.0.0`|2.0.2|2.0.2|
|[`url_launcher_platform_interface`]|`^2.0.0`|2.0.5|2.0.5|
|[`url_launcher_web`]|`^2.0.0`|2.0.6|2.0.6|
|[`url_launcher_windows`]|`^2.0.0`|2.0.2|2.0.2|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`characters`]|-|1.2.0|1.2.0|
|[`collection`]|-|1.15.0|1.15.0|
|[`flutter_web_plugins`]|-|0.0.0|0.0.0|
|[`js`]|-|0.6.3|0.6.4|
|[`meta`]|-|1.7.0|1.7.0|
|[`sky_engine`]|-|0.0.99|0.0.99|
|[`typed_data`]|-|1.3.0|1.3.0|
|[`vector_math`]|-|2.1.1|2.1.1|
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
