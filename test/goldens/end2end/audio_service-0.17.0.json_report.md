## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/lib/main.dart`

## 20/20 Support multiple platforms

### [*] 20/20 points: Supports 3 of 3 possible platforms (**iOS**, **Android**, **Web**)

Found 8 issues. Showing the first 2:


Consider supporting these prerelease platforms:

<details>
<summary>
Package does not support Flutter platform `Windows`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that declares support for platforms: `Android`, `iOS`, `macOS`, `Web`.
</details>

## 30/30 Pass static analysis

### [*] 30/30 points: code has no errors, warnings, lints, or formatting issues


## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`audio_session`]|`^0.1.0`|0.1.2|0.1.2|
|[`flutter`]|`flutter`|0.0.0|0.0.0|
|[`flutter_cache_manager`]|`^3.0.0`|3.1.1|3.1.1|
|[`flutter_isolate`]|`^2.0.0`|2.0.0|2.0.0|
|[`flutter_web_plugins`]|`flutter`|0.0.0|0.0.0|
|[`js`]|`^0.6.3`|0.6.3|0.6.3|
|[`rxdart`]|`^0.26.0`|0.26.0|**0.27.1**|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`archive`]|-|3.1.2|3.1.2|
|[`async`]|-|2.7.0|2.7.0|
|[`characters`]|-|1.1.0|1.1.0|
|[`charcode`]|-|1.2.0|1.2.0|
|[`clock`]|-|1.1.0|1.1.0|
|[`collection`]|-|1.15.0|1.15.0|
|[`crypto`]|-|3.0.1|3.0.1|
|[`ffi`]|-|1.1.2|1.1.2|
|[`file`]|-|6.1.1|6.1.1|
|[`http`]|-|0.13.3|0.13.3|
|[`http_parser`]|-|4.0.0|4.0.0|
|[`image`]|-|3.0.2|3.0.2|
|[`meta`]|-|1.3.0|1.4.0|
|[`path`]|-|1.8.0|1.8.0|
|[`path_provider`]|-|2.0.2|2.0.2|
|[`path_provider_linux`]|-|2.0.0|2.0.0|
|[`path_provider_macos`]|-|2.0.0|2.0.0|
|[`path_provider_platform_interface`]|-|2.0.1|2.0.1|
|[`path_provider_windows`]|-|2.0.1|2.0.1|
|[`pedantic`]|-|1.11.0|1.11.0|
|[`petitparser`]|-|4.1.0|4.2.0|
|[`platform`]|-|3.0.0|3.0.0|
|[`plugin_platform_interface`]|-|2.0.0|2.0.0|
|[`process`]|-|4.2.1|4.2.1|
|[`sky_engine`]|-|0.0.99|0.0.99|
|[`source_span`]|-|1.8.1|1.8.1|
|[`sqflite`]|-|2.0.0+3|2.0.0+3|
|[`sqflite_common`]|-|2.0.0+2|2.0.0+2|
|[`string_scanner`]|-|1.1.0|1.1.0|
|[`synchronized`]|-|3.0.0|3.0.0|
|[`term_glyph`]|-|1.2.0|1.2.0|
|[`typed_data`]|-|1.3.0|1.3.0|
|[`uuid`]|-|3.0.4|3.0.4|
|[`vector_math`]|-|2.1.0|2.1.0|
|[`win32`]|-|2.1.4|2.1.4|
|[`xdg_directories`]|-|0.2.0|0.2.0|
|[`xml`]|-|5.1.2|5.1.2|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`audio_session`]: https://pub.dev/packages/audio_session
[`flutter`]: https://pub.dev/packages/flutter
[`flutter_cache_manager`]: https://pub.dev/packages/flutter_cache_manager
[`flutter_isolate`]: https://pub.dev/packages/flutter_isolate
[`flutter_web_plugins`]: https://pub.dev/packages/flutter_web_plugins
[`js`]: https://pub.dev/packages/js
[`rxdart`]: https://pub.dev/packages/rxdart
[`archive`]: https://pub.dev/packages/archive
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
[`image`]: https://pub.dev/packages/image
[`meta`]: https://pub.dev/packages/meta
[`path`]: https://pub.dev/packages/path
[`path_provider`]: https://pub.dev/packages/path_provider
[`path_provider_linux`]: https://pub.dev/packages/path_provider_linux
[`path_provider_macos`]: https://pub.dev/packages/path_provider_macos
[`path_provider_platform_interface`]: https://pub.dev/packages/path_provider_platform_interface
[`path_provider_windows`]: https://pub.dev/packages/path_provider_windows
[`pedantic`]: https://pub.dev/packages/pedantic
[`petitparser`]: https://pub.dev/packages/petitparser
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
[`xml`]: https://pub.dev/packages/xml

<details>
<summary>
The constraint `^0.26.0` on rxdart does not support the stable version `0.27.0`.
</summary>

Try running `dart pub upgrade --major-versions rxdart` to update the constraint.
</details>

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
