## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.

## 10/10 Provide documentation

### [*] 10/10 points: Package has an example


## 20/20 Platform support

### [*] 20/20 points: Supports 4 of 6 possible platforms (**iOS**, **Android**, **Web**, Windows, **macOS**, Linux)

* ✓ Android
* ✓ iOS
* ✓ macOS
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
Package does not support platform `Web`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that imports:
* `package:flutter_cache_manager/flutter_cache_manager.dart` that imports:
* `package:flutter_cache_manager/src/storage/cache_info_repositories/cache_info_repositories.dart` that imports:
* `package:flutter_cache_manager/src/storage/cache_info_repositories/json_cache_info_repository.dart` that imports:
* `package:path_provider/path_provider.dart` that declares support for platforms: `Android`, `iOS`, `Windows`, `Linux`, `macOS`.
</details>

## 50/50 Pass static analysis

### [*] 50/50 points: code has no errors, warnings, lints, or formatting issues


## 30/40 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`audio_service_platform_interface`]|`^0.1.0`|0.1.1|0.1.1|
|[`audio_service_web`]|`^0.1.1`|0.1.2|0.1.2|
|[`audio_session`]|`^0.1.6+1`|0.1.19|0.1.19|
|[`clock`]|`^1.1.0`|1.1.1|1.1.1|
|[`flutter`]|`flutter`|0.0.0|0.0.0|
|[`flutter_cache_manager`]|`^3.0.1`|3.3.2|3.3.2|
|[`flutter_web_plugins`]|`flutter`|0.0.0|0.0.0|
|[`js`]|`^0.6.3`|0.6.7|**0.7.1**|
|[`rxdart`]|`>=0.26.0 <0.28.0`|0.27.7|0.27.7|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`async`]|-|2.11.0|2.11.0|
|[`characters`]|-|1.3.0|1.3.0|
|[`collection`]|-|1.18.0|1.18.0|
|[`crypto`]|-|3.0.3|3.0.3|
|[`ffi`]|-|2.1.2|2.1.2|
|[`file`]|-|7.0.0|7.0.0|
|[`fixnum`]|-|1.1.0|1.1.0|
|[`http`]|-|1.2.1|1.2.1|
|[`http_parser`]|-|4.0.2|4.0.2|
|[`material_color_utilities`]|-|0.8.0|0.11.1|
|[`meta`]|-|1.12.0|1.15.0|
|[`path`]|-|1.9.0|1.9.0|
|[`path_provider`]|-|2.1.3|2.1.3|
|[`path_provider_android`]|-|2.2.5|2.2.5|
|[`path_provider_foundation`]|-|2.4.0|2.4.0|
|[`path_provider_linux`]|-|2.2.1|2.2.1|
|[`path_provider_platform_interface`]|-|2.1.2|2.1.2|
|[`path_provider_windows`]|-|2.2.1|2.2.1|
|[`platform`]|-|3.1.4|3.1.4|
|[`plugin_platform_interface`]|-|2.1.8|2.1.8|
|[`sky_engine`]|-|0.0.99|0.0.99|
|[`source_span`]|-|1.10.0|1.10.0|
|[`sprintf`]|-|7.0.0|7.0.0|
|[`sqflite`]|-|2.3.3+1|2.3.3+1|
|[`sqflite_common`]|-|2.5.4|2.5.4|
|[`string_scanner`]|-|1.2.0|1.2.0|
|[`synchronized`]|-|3.1.0+1|3.1.0+1|
|[`term_glyph`]|-|1.2.1|1.2.1|
|[`typed_data`]|-|1.3.2|1.3.2|
|[`uuid`]|-|4.4.0|4.4.0|
|[`vector_math`]|-|2.1.4|2.1.4|
|[`web`]|-|0.5.1|0.5.1|
|[`win32`]|-|5.5.1|5.5.1|
|[`xdg_directories`]|-|1.0.4|1.0.4|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`audio_service_platform_interface`]: https://pub.dev/packages/audio_service_platform_interface
[`audio_service_web`]: https://pub.dev/packages/audio_service_web
[`audio_session`]: https://pub.dev/packages/audio_session
[`clock`]: https://pub.dev/packages/clock
[`flutter`]: https://pub.dev/packages/flutter
[`flutter_cache_manager`]: https://pub.dev/packages/flutter_cache_manager
[`flutter_web_plugins`]: https://pub.dev/packages/flutter_web_plugins
[`js`]: https://pub.dev/packages/js
[`rxdart`]: https://pub.dev/packages/rxdart
[`async`]: https://pub.dev/packages/async
[`characters`]: https://pub.dev/packages/characters
[`collection`]: https://pub.dev/packages/collection
[`crypto`]: https://pub.dev/packages/crypto
[`ffi`]: https://pub.dev/packages/ffi
[`file`]: https://pub.dev/packages/file
[`fixnum`]: https://pub.dev/packages/fixnum
[`http`]: https://pub.dev/packages/http
[`http_parser`]: https://pub.dev/packages/http_parser
[`material_color_utilities`]: https://pub.dev/packages/material_color_utilities
[`meta`]: https://pub.dev/packages/meta
[`path`]: https://pub.dev/packages/path
[`path_provider`]: https://pub.dev/packages/path_provider
[`path_provider_android`]: https://pub.dev/packages/path_provider_android
[`path_provider_foundation`]: https://pub.dev/packages/path_provider_foundation
[`path_provider_linux`]: https://pub.dev/packages/path_provider_linux
[`path_provider_platform_interface`]: https://pub.dev/packages/path_provider_platform_interface
[`path_provider_windows`]: https://pub.dev/packages/path_provider_windows
[`platform`]: https://pub.dev/packages/platform
[`plugin_platform_interface`]: https://pub.dev/packages/plugin_platform_interface
[`sky_engine`]: https://pub.dev/packages/sky_engine
[`source_span`]: https://pub.dev/packages/source_span
[`sprintf`]: https://pub.dev/packages/sprintf
[`sqflite`]: https://pub.dev/packages/sqflite
[`sqflite_common`]: https://pub.dev/packages/sqflite_common
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`synchronized`]: https://pub.dev/packages/synchronized
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data
[`uuid`]: https://pub.dev/packages/uuid
[`vector_math`]: https://pub.dev/packages/vector_math
[`web`]: https://pub.dev/packages/web
[`win32`]: https://pub.dev/packages/win32
[`xdg_directories`]: https://pub.dev/packages/xdg_directories

<details>
<summary>
The constraint `^0.6.3` on js does not support the stable version `0.7.0`.
</summary>

Try running `dart pub upgrade --major-versions js` to update the constraint.
</details>

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.