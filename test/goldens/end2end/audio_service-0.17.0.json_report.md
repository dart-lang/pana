## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/lib/main.dart`

## 20/20 Platform Support

### [*] 20/20 points: Supports 4 of 6 possible platforms (**iOS**, **Android**, **Web**, Windows, **MacOS**, Linux)

* ✓ Android
* ✓ iOS
* ✓ MacOS
* ✓ Web

These platforms are not supported:

<details>
<summary>
Package does not support platform `Windows`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that declares support for platforms: `Android`, `iOS`, `macOS`, `Web`.
</details>
<details>
<summary>
Package does not support platform `Linux`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that declares support for platforms: `Android`, `iOS`, `macOS`, `Web`.
</details>

These issues are present but do not affect the score, because they may not originate in your package:

<details>
<summary>
Package does not support platform `macOS`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that imports:
* `package:flutter_isolate/flutter_isolate.dart` that declares support for platforms: `Android`, `iOS`.
</details>
<details>
<summary>
Package does not support platform `Web`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that imports:
* `package:flutter_isolate/flutter_isolate.dart` that declares support for platforms: `Android`, `iOS`.
</details>

## 0/30 Pass static analysis

### [x] 0/30 points: code has no errors, warnings, lints, or formatting issues

<details>
<summary>
ERROR: The method 'setMockMethodCallHandler' isn't defined for the type 'MethodChannel'.
</summary>

`lib/audio_service.dart:674:16`

```
    ╷
674 │               .setMockMethodCallHandler(handler);
    │                ^^^^^^^^^^^^^^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/audio_service.dart`
</details>
<details>
<summary>
ERROR: The method 'setMockMethodCallHandler' isn't defined for the type 'MethodChannel'.
</summary>

`lib/audio_service.dart:1266:12`

```
     ╷
1266 │           .setMockMethodCallHandler(handler);
     │            ^^^^^^^^^^^^^^^^^^^^^^^^
     ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/audio_service.dart`
</details>

## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`audio_session`]|`^0.1.0`|0.1.6+1|0.1.6+1|
|[`flutter`]|`flutter`|0.0.0|0.0.0|
|[`flutter_cache_manager`]|`^3.0.0`|3.3.0|3.3.0|
|[`flutter_isolate`]|`^2.0.0`|2.0.0|2.0.0|
|[`flutter_web_plugins`]|`flutter`|0.0.0|0.0.0|
|[`js`]|`^0.6.3`|0.6.3|0.6.3|
|[`rxdart`]|`^0.26.0`|0.26.0|**0.27.3**|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`async`]|-|2.8.2|2.8.2|
|[`characters`]|-|1.2.0|1.2.0|
|[`charcode`]|-|1.3.1|1.3.1|
|[`clock`]|-|1.1.0|1.1.0|
|[`collection`]|-|1.15.0|1.15.0|
|[`crypto`]|-|3.0.1|3.0.1|
|[`ffi`]|-|1.1.2|1.1.2|
|[`file`]|-|6.1.2|6.1.2|
|[`http`]|-|0.13.4|0.13.4|
|[`http_parser`]|-|4.0.0|4.0.0|
|[`meta`]|-|1.7.0|1.7.0|
|[`path`]|-|1.8.0|1.8.0|
|[`path_provider`]|-|2.0.8|2.0.8|
|[`path_provider_android`]|-|2.0.9|2.0.9|
|[`path_provider_ios`]|-|2.0.7|2.0.7|
|[`path_provider_linux`]|-|2.1.4|2.1.4|
|[`path_provider_macos`]|-|2.0.4|2.0.4|
|[`path_provider_platform_interface`]|-|2.0.1|2.0.1|
|[`path_provider_windows`]|-|2.0.4|2.0.4|
|[`pedantic`]|-|1.11.1|1.11.1|
|[`platform`]|-|3.1.0|3.1.0|
|[`plugin_platform_interface`]|-|2.0.2|2.0.2|
|[`process`]|-|4.2.4|4.2.4|
|[`sky_engine`]|-|0.0.99|0.0.99|
|[`source_span`]|-|1.8.1|1.8.1|
|[`sqflite`]|-|2.0.1|2.0.1|
|[`sqflite_common`]|-|2.1.0|2.1.0|
|[`string_scanner`]|-|1.1.0|1.1.0|
|[`synchronized`]|-|3.0.0|3.0.0|
|[`term_glyph`]|-|1.2.0|1.2.0|
|[`typed_data`]|-|1.3.0|1.3.0|
|[`uuid`]|-|3.0.5|3.0.5|
|[`vector_math`]|-|2.1.1|2.1.1|
|[`win32`]|-|2.3.1|2.3.1|
|[`xdg_directories`]|-|0.2.0|0.2.0|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`audio_session`]: https://pub.dev/packages/audio_session
[`flutter`]: https://pub.dev/packages/flutter
[`flutter_cache_manager`]: https://pub.dev/packages/flutter_cache_manager
[`flutter_isolate`]: https://pub.dev/packages/flutter_isolate
[`flutter_web_plugins`]: https://pub.dev/packages/flutter_web_plugins
[`js`]: https://pub.dev/packages/js
[`rxdart`]: https://pub.dev/packages/rxdart
[`async`]: https://pub.dev/packages/async
[`characters`]: https://pub.dev/packages/characters
[`charcode`]: https://pub.dev/packages/charcode
[`clock`]: https://pub.dev/packages/clock
[`collection`]: https://pub.dev/packages/collection
[`crypto`]: https://pub.dev/packages/crypto
[`ffi`]: https://pub.dev/packages/ffi
[`file`]: https://pub.dev/packages/file
[`http`]: https://pub.dev/packages/http
[`http_parser`]: https://pub.dev/packages/http_parser
[`meta`]: https://pub.dev/packages/meta
[`path`]: https://pub.dev/packages/path
[`path_provider`]: https://pub.dev/packages/path_provider
[`path_provider_android`]: https://pub.dev/packages/path_provider_android
[`path_provider_ios`]: https://pub.dev/packages/path_provider_ios
[`path_provider_linux`]: https://pub.dev/packages/path_provider_linux
[`path_provider_macos`]: https://pub.dev/packages/path_provider_macos
[`path_provider_platform_interface`]: https://pub.dev/packages/path_provider_platform_interface
[`path_provider_windows`]: https://pub.dev/packages/path_provider_windows
[`pedantic`]: https://pub.dev/packages/pedantic
[`platform`]: https://pub.dev/packages/platform
[`plugin_platform_interface`]: https://pub.dev/packages/plugin_platform_interface
[`process`]: https://pub.dev/packages/process
[`sky_engine`]: https://pub.dev/packages/sky_engine
[`source_span`]: https://pub.dev/packages/source_span
[`sqflite`]: https://pub.dev/packages/sqflite
[`sqflite_common`]: https://pub.dev/packages/sqflite_common
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`synchronized`]: https://pub.dev/packages/synchronized
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data
[`uuid`]: https://pub.dev/packages/uuid
[`vector_math`]: https://pub.dev/packages/vector_math
[`win32`]: https://pub.dev/packages/win32
[`xdg_directories`]: https://pub.dev/packages/xdg_directories

<details>
<summary>
The constraint `^0.26.0` on rxdart does not support the stable version `0.27.0`.
</summary>

Try running `dart pub upgrade --major-versions rxdart` to update the constraint.
</details>

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
