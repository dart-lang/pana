## 30/30 Follow Dart file conventions

### [~] 10/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
Issue tracker URL doesn't exist.
</summary>

At the time of the analysis `https://github.com/flutter/flutter/issues?q=is%3Aissue+is%3Aopen+label%3A%22p%3A+url_launcher%22` was unreachable. Make sure that the website is reachable via [`HEAD`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/HEAD) requests.
</details>

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `BSD-3-Clause`.


## 20/20 Provide documentation

### [*] 10/10 points: 20% or more of the public API has dartdoc comments

34 out of 37 API elements (91.9 %) have documentation comments.

Some symbols that are missing documentation: `link`, `url_launcher`, `url_launcher_string`.

### [*] 10/10 points: Package has an example


## 20/20 Platform support

### [*] 20/20 points: Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **macOS**, **Linux**)

* ✓ Android

* ✓ iOS

* ✓ Windows

* ✓ Linux

* ✓ macOS

* ✓ Web

### [*] 0/0 points: WASM compatibility

This package is compatible with runtime `wasm`, and will be rewarded additional points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## 40/50 Pass static analysis

### [~] 40/50 points: code has no errors, warnings, lints, or formatting issues

<details>
<summary>
INFO: 'launch' is deprecated and shouldn't be used. Use launchUrl instead.
</summary>

`lib/src/legacy_api.dart:150:6`

```
    ╷
150 │ /// [launch] predates multi-window support, and it doesn't have enough context
    │      ^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/src/legacy_api.dart`
</details>


## 40/40 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`flutter`]|`flutter`|0.0.0|0.0.0|
|[`url_launcher_android`]|`^6.3.0`|6.3.14|6.3.14|
|[`url_launcher_ios`]|`^6.2.4`|6.3.2|6.3.2|
|[`url_launcher_linux`]|`^3.1.0`|3.2.1|3.2.1|
|[`url_launcher_macos`]|`^3.1.0`|3.2.2|3.2.2|
|[`url_launcher_platform_interface`]|`^2.3.0`|2.3.2|2.3.2|
|[`url_launcher_web`]|`^2.2.0`|2.4.0|2.4.0|
|[`url_launcher_windows`]|`^3.1.0`|3.1.4|3.1.4|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`characters`]|-|1.4.0|1.4.0|
|[`collection`]|-|1.19.1|1.19.1|
|[`flutter_web_plugins`]|-|0.0.0|0.0.0|
|[`material_color_utilities`]|-|0.11.1|0.12.0|
|[`meta`]|-|1.16.0|1.16.0|
|[`plugin_platform_interface`]|-|2.1.8|2.1.8|
|[`sky_engine`]|-|0.0.0|0.0.0|
|[`vector_math`]|-|2.1.4|2.1.4|
|[`web`]|-|1.1.0|1.1.0|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`flutter`]: https://pub.dev/packages/flutter
[`url_launcher_android`]: https://pub.dev/packages/url_launcher_android
[`url_launcher_ios`]: https://pub.dev/packages/url_launcher_ios
[`url_launcher_linux`]: https://pub.dev/packages/url_launcher_linux
[`url_launcher_macos`]: https://pub.dev/packages/url_launcher_macos
[`url_launcher_platform_interface`]: https://pub.dev/packages/url_launcher_platform_interface
[`url_launcher_web`]: https://pub.dev/packages/url_launcher_web
[`url_launcher_windows`]: https://pub.dev/packages/url_launcher_windows
[`characters`]: https://pub.dev/packages/characters
[`collection`]: https://pub.dev/packages/collection
[`flutter_web_plugins`]: https://pub.dev/packages/flutter_web_plugins
[`material_color_utilities`]: https://pub.dev/packages/material_color_utilities
[`meta`]: https://pub.dev/packages/meta
[`plugin_platform_interface`]: https://pub.dev/packages/plugin_platform_interface
[`sky_engine`]: https://pub.dev/packages/sky_engine
[`vector_math`]: https://pub.dev/packages/vector_math
[`web`]: https://pub.dev/packages/web

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.
