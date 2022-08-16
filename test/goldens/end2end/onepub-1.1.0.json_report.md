## 10/30 Follow Dart file conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
Failed to verify repository URL.
</summary>

Please provide a valid [`repository`](https://dart.dev/tools/pub/pubspec#repository) URL in `pubspec.yaml`, such that:

 * `repository` can be cloned,
 * a clone of the repository contains a `pubspec.yaml`, which:,
    * contains `name: onepub`,
    * contains a `version` property, and,
    * does not contain a `publish_to` property.

`pubspec.yaml` from the repository URL missmatch: expected `https://github.com/noojee/onepub.dev` but got `https://github.com/onepub-dev/onepub`.
</details>

### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


### [x] 0/10 points: Use an OSI-approved license

<details>
<summary>
No license was recognized.
</summary>

Consider using an [OSI-approved license](https://opensource.org/licenses) in the `LICENSE` file to share with the community.
</details>

## 0/10 Provide documentation

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>

## 20/20 Platform support

### [*] 20/20 points: Supports 3 of 6 possible platforms (iOS, Android, Web, **Windows**, **MacOS**, **Linux**)

* ✓ Linux
* ✓ MacOS
* ✓ Windows

These platforms are not supported:

<details>
<summary>
Android
</summary>

Cannot assign Android automatically to a binary only package.
</details>
<details>
<summary>
iOS
</summary>

Cannot assign iOS automatically to a binary only package.
</details>
<details>
<summary>
Web
</summary>

Cannot assign Web automatically to a binary only package.
</details>

## 30/30 Pass static analysis

### [*] 30/30 points: code has no errors, warnings, lints, or formatting issues


## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`dcli`]|`^1.15.5`|1.33.0|1.33.0|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`archive`]|-|3.3.1|3.3.1|
|[`args`]|-|2.3.1|2.3.1|
|[`async`]|-|2.9.0|2.9.0|
|[`basic_utils`]|-|3.9.4|4.5.2|
|[`chunked_stream`]|-|1.4.1|1.4.1|
|[`circular_buffer`]|-|0.11.0|0.11.0|
|[`clock`]|-|1.1.1|1.1.1|
|[`collection`]|-|1.16.0|1.16.0|
|[`convert`]|-|3.0.2|3.0.2|
|[`crypto`]|-|3.0.2|3.0.2|
|[`csv`]|-|5.0.1|5.0.1|
|[`dart_console2`]|-|2.0.0|2.0.0|
|[`dcli_core`]|-|1.33.1|1.33.1|
|[`equatable`]|-|2.0.3|2.0.3|
|[`ffi`]|-|2.0.1|2.0.1|
|[`file`]|-|6.1.2|6.1.2|
|[`file_utils`]|-|1.0.1|1.0.1|
|[`glob`]|-|2.1.0|2.1.0|
|[`globbing`]|-|1.0.0|1.0.0|
|[`http`]|-|0.13.5|0.13.5|
|[`http_parser`]|-|4.0.1|4.0.1|
|[`ini`]|-|2.1.0|2.1.0|
|[`intl`]|-|0.17.0|0.17.0|
|[`js`]|-|0.6.4|0.6.4|
|[`json_annotation`]|-|4.6.0|4.6.0|
|[`logging`]|-|1.0.2|1.0.2|
|[`matcher`]|-|0.12.12|0.12.12|
|[`meta`]|-|1.8.0|1.8.0|
|[`mime`]|-|1.0.2|1.0.2|
|[`path`]|-|1.8.2|1.8.2|
|[`pointycastle`]|-|3.6.1|3.6.1|
|[`posix`]|-|4.0.0|4.0.0|
|[`pub_semver`]|-|2.1.1|2.1.1|
|[`pubspec2`]|-|2.4.1|2.4.1|
|[`quiver`]|-|3.1.0|3.1.0|
|[`random_string`]|-|2.3.1|2.3.1|
|[`scope`]|-|2.2.1|2.2.1|
|[`settings_yaml`]|-|3.4.2|3.4.2|
|[`source_span`]|-|1.9.1|1.9.1|
|[`stack_trace`]|-|1.10.0|1.10.0|
|[`stacktrace_impl`]|-|2.3.0|2.3.0|
|[`string_scanner`]|-|1.1.1|1.1.1|
|[`system_info2`]|-|2.0.4|2.0.4|
|[`term_glyph`]|-|1.2.1|1.2.1|
|[`typed_data`]|-|1.3.1|1.3.1|
|[`uri`]|-|1.0.0|1.0.0|
|[`uuid`]|-|3.0.6|3.0.6|
|[`validators2`]|-|3.0.0|3.0.0|
|[`vin_decoder`]|-|0.2.1-nullsafety|0.2.1-nullsafety|
|[`win32`]|-|2.7.0|2.7.0|
|[`yaml`]|-|3.1.1|3.1.1|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`dcli`]: https://pub.dev/packages/dcli
[`archive`]: https://pub.dev/packages/archive
[`args`]: https://pub.dev/packages/args
[`async`]: https://pub.dev/packages/async
[`basic_utils`]: https://pub.dev/packages/basic_utils
[`chunked_stream`]: https://pub.dev/packages/chunked_stream
[`circular_buffer`]: https://pub.dev/packages/circular_buffer
[`clock`]: https://pub.dev/packages/clock
[`collection`]: https://pub.dev/packages/collection
[`convert`]: https://pub.dev/packages/convert
[`crypto`]: https://pub.dev/packages/crypto
[`csv`]: https://pub.dev/packages/csv
[`dart_console2`]: https://pub.dev/packages/dart_console2
[`dcli_core`]: https://pub.dev/packages/dcli_core
[`equatable`]: https://pub.dev/packages/equatable
[`ffi`]: https://pub.dev/packages/ffi
[`file`]: https://pub.dev/packages/file
[`file_utils`]: https://pub.dev/packages/file_utils
[`glob`]: https://pub.dev/packages/glob
[`globbing`]: https://pub.dev/packages/globbing
[`http`]: https://pub.dev/packages/http
[`http_parser`]: https://pub.dev/packages/http_parser
[`ini`]: https://pub.dev/packages/ini
[`intl`]: https://pub.dev/packages/intl
[`js`]: https://pub.dev/packages/js
[`json_annotation`]: https://pub.dev/packages/json_annotation
[`logging`]: https://pub.dev/packages/logging
[`matcher`]: https://pub.dev/packages/matcher
[`meta`]: https://pub.dev/packages/meta
[`mime`]: https://pub.dev/packages/mime
[`path`]: https://pub.dev/packages/path
[`pointycastle`]: https://pub.dev/packages/pointycastle
[`posix`]: https://pub.dev/packages/posix
[`pub_semver`]: https://pub.dev/packages/pub_semver
[`pubspec2`]: https://pub.dev/packages/pubspec2
[`quiver`]: https://pub.dev/packages/quiver
[`random_string`]: https://pub.dev/packages/random_string
[`scope`]: https://pub.dev/packages/scope
[`settings_yaml`]: https://pub.dev/packages/settings_yaml
[`source_span`]: https://pub.dev/packages/source_span
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`stacktrace_impl`]: https://pub.dev/packages/stacktrace_impl
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`system_info2`]: https://pub.dev/packages/system_info2
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data
[`uri`]: https://pub.dev/packages/uri
[`uuid`]: https://pub.dev/packages/uuid
[`validators2`]: https://pub.dev/packages/validators2
[`vin_decoder`]: https://pub.dev/packages/vin_decoder
[`win32`]: https://pub.dev/packages/win32
[`yaml`]: https://pub.dev/packages/yaml


### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
