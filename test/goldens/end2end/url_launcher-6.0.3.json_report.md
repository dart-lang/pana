## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example


## 20/20 Platform support

### [*] 20/20 points: Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **MacOS**, **Linux**)

* ✓ Android
* ✓ iOS
* ✓ Windows
* ✓ Linux
* ✓ MacOS
* ✓ Web

## 10/30 Pass static analysis

### [x] 10/30 points: code has no errors, warnings, lints, or formatting issues

Found 5 issues. Showing the first 2:

<details>
<summary>
WARNING: The '!' will have no effect because the receiver can't be null.
</summary>

`lib/url_launcher.dart:89:32`

```
   ╷
89 │         WidgetsBinding.instance!.renderView.automaticSystemUiAdjustment;
   │                                ^
   ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/url_launcher.dart`
</details>
<details>
<summary>
WARNING: The '!' will have no effect because the receiver can't be null.
</summary>

`lib/url_launcher.dart:90:28`

```
   ╷
90 │     WidgetsBinding.instance!.renderView.automaticSystemUiAdjustment = false;
   │                            ^
   ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/url_launcher.dart`
</details>

## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`flutter`]|`flutter`|0.0.0|0.0.0|
|[`url_launcher_linux`]|`^2.0.0`|2.0.3|**3.0.0**|
|[`url_launcher_macos`]|`^2.0.0`|2.0.3|**3.0.0**|
|[`url_launcher_platform_interface`]|`^2.0.0`|2.0.5|2.0.5|
|[`url_launcher_web`]|`^2.0.0`|2.0.9|2.0.9|
|[`url_launcher_windows`]|`^2.0.0`|2.0.2|**3.0.0**|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`characters`]|-|1.2.0|1.2.0|
|[`collection`]|-|1.15.0|1.16.0|
|[`flutter_web_plugins`]|-|0.0.0|0.0.0|
|[`js`]|-|0.6.4|0.6.4|
|[`material_color_utilities`]|-|0.1.4|0.1.4|
|[`meta`]|-|1.7.0|1.7.0|
|[`sky_engine`]|-|0.0.99|0.0.99|
|[`typed_data`]|-|1.3.0|1.3.0|
|[`vector_math`]|-|2.1.2|2.1.2|
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
[`material_color_utilities`]: https://pub.dev/packages/material_color_utilities
[`meta`]: https://pub.dev/packages/meta
[`sky_engine`]: https://pub.dev/packages/sky_engine
[`typed_data`]: https://pub.dev/packages/typed_data
[`vector_math`]: https://pub.dev/packages/vector_math

Found 3 issues. Showing the first 2:

<details>
<summary>
The constraint `^2.0.0` on url_launcher_linux does not support the stable version `3.0.0`.
</summary>

Try running `dart pub upgrade --major-versions url_launcher_linux` to update the constraint.
</details>
<details>
<summary>
The constraint `^2.0.0` on url_launcher_macos does not support the stable version `3.0.0`.
</summary>

Try running `dart pub upgrade --major-versions url_launcher_macos` to update the constraint.
</details>

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
