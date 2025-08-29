## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `BSD-3-Clause`.


## 20/20 Provide documentation

### [*] 10/10 points: 20% or more of the public API has dartdoc comments

50 out of 51 API elements (98.0 %) have documentation comments.

Some symbols that are missing documentation: `camera_web`.

### [*] 10/10 points: Package has an example


## 20/20 Platform support

### [*] 20/20 points: Supports 1 of 6 possible platforms (iOS, Android, **Web**, Windows, macOS, Linux)

* ✓ Web


These platforms are not supported:

<details>
<summary>
Package does not support platform `Android`.
</summary>

Because:
* `package:camera_web/camera_web.dart` that declares support for platforms: `Web`.
</details>

<details>
<summary>
Package does not support platform `iOS`.
</summary>

Because:
* `package:camera_web/camera_web.dart` that declares support for platforms: `Web`.
</details>

<details>
<summary>
Package does not support platform `Windows`.
</summary>

Because:
* `package:camera_web/camera_web.dart` that declares support for platforms: `Web`.
</details>

<details>
<summary>
Package does not support platform `Linux`.
</summary>

Because:
* `package:camera_web/camera_web.dart` that declares support for platforms: `Web`.
</details>

<details>
<summary>
Package does not support platform `macOS`.
</summary>

Because:
* `package:camera_web/camera_web.dart` that declares support for platforms: `Web`.
</details>

### [*] 0/0 points: WASM compatibility

This package is compatible with runtime `wasm`, and will be rewarded additional points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## 40/50 Pass static analysis

### [~] 40/50 points: code has no errors, warnings, lints, or formatting issues

<details>
<summary>
INFO: 'drawImageScaled' is deprecated and shouldn't be used. See CanvasRenderingContext2D.drawImage.
</summary>

`lib/src/camera.dart:268:22`

```
    ╷
268 │     canvas.context2D.drawImageScaled(
    │                      ^^^^^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/src/camera.dart`
</details>


## 40/40 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|Notes|
|:-|:-|:-|:-|:-|
|[`camera_platform_interface`]|`^2.6.0`|2.10.0|2.10.0||
|[`stream_transform`]|`^2.0.0`|2.1.1|2.1.1||
|[`web`]|`>=0.5.1 <2.0.0`|1.1.1|1.1.1||

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|Notes|
|:-|:-|:-|:-|:-|
|[`characters`]|-|1.4.0|1.4.1||
|[`collection`]|-|1.19.1|1.19.1||
|[`cross_file`]|-|0.3.4+2|0.3.4+2||
|[`material_color_utilities`]|-|0.11.1|0.13.0||
|[`meta`]|-|1.17.0|1.17.0||
|[`plugin_platform_interface`]|-|2.1.8|2.1.8||
|[`vector_math`]|-|2.2.0|2.2.0||
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`camera_platform_interface`]: https://pub.dev/packages/camera_platform_interface
[`stream_transform`]: https://pub.dev/packages/stream_transform
[`web`]: https://pub.dev/packages/web
[`characters`]: https://pub.dev/packages/characters
[`collection`]: https://pub.dev/packages/collection
[`cross_file`]: https://pub.dev/packages/cross_file
[`material_color_utilities`]: https://pub.dev/packages/material_color_utilities
[`meta`]: https://pub.dev/packages/meta
[`plugin_platform_interface`]: https://pub.dev/packages/plugin_platform_interface
[`vector_math`]: https://pub.dev/packages/vector_math

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.
