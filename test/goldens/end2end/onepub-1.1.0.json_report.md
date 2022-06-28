## 10/20 Follow Dart file conventions

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
|[`dcli`]|`^1.15.5`|1.16.2|1.16.2|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`archive`]|-|3.1.11|3.1.11|
|[`args`]|-|2.3.0|2.3.0|
|[`async`]|-|2.8.2|2.8.2|
|[`basic_utils`]|-|3.9.4|4.0.1|
|[`charcode`]|-|1.3.1|1.3.1|
|[`chunked_stream`]|-|1.4.1|1.4.1|
|[`circular_buffer`]|-|0.10.0|0.10.0|
|[`collection`]|-|1.15.0|1.15.0|
|[`convert`]|-|3.0.1|3.0.1|
|[`crypto`]|-|3.0.1|3.0.1|
|[`csv`]|-|5.0.1|5.0.1|
|[`dart_console`]|-|1.0.0|1.0.0|
|[`dcli_core`]|-|0.0.6|0.0.6|
|[`di_zone2`]|-|1.0.2|1.0.2|
|[`equatable`]|-|2.0.3|2.0.3|
|[`ffi`]|-|1.1.2|1.1.2|
|[`file`]|-|6.1.2|6.1.2|
|[`glob`]|-|2.0.2|2.0.2|
|[`http`]|-|0.13.4|0.13.4|
|[`http_parser`]|-|4.0.0|4.0.0|
|[`ini`]|-|2.1.0|2.1.0|
|[`js`]|-|0.6.4|0.6.4|
|[`json_annotation`]|-|4.4.0|4.4.0|
|[`logging`]|-|1.0.2|1.0.2|
|[`matcher`]|-|0.12.11|0.12.11|
|[`meta`]|-|1.7.0|1.7.0|
|[`mime`]|-|1.0.1|1.0.1|
|[`path`]|-|1.8.1|1.8.1|
|[`pointycastle`]|-|3.5.0|3.5.0|
|[`posix`]|-|3.0.0|3.0.0|
|[`pub_semver`]|-|2.1.0|2.1.0|
|[`pubspec`]|-|2.0.1|2.0.1|
|[`quiver`]|-|3.0.1+1|3.0.1+1|
|[`random_string`]|-|2.3.1|2.3.1|
|[`settings_yaml`]|-|3.3.1|3.3.1|
|[`source_span`]|-|1.8.2|1.8.2|
|[`stack_trace`]|-|1.10.0|1.10.0|
|[`stacktrace_impl`]|-|2.3.0|2.3.0|
|[`string_scanner`]|-|1.1.0|1.1.0|
|[`term_glyph`]|-|1.2.0|1.2.0|
|[`typed_data`]|-|1.3.0|1.3.0|
|[`uri`]|-|1.0.0|1.0.0|
|[`uuid`]|-|3.0.5|3.0.5|
|[`validators2`]|-|3.0.0|3.0.0|
|[`vin_decoder`]|-|0.2.1-nullsafety|0.2.1-nullsafety|
|[`win32`]|-|2.3.10|2.3.10|
|[`yaml`]|-|3.1.0|3.1.0|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`dcli`]: https://pub.dev/packages/dcli
[`archive`]: https://pub.dev/packages/archive
[`args`]: https://pub.dev/packages/args
[`async`]: https://pub.dev/packages/async
[`basic_utils`]: https://pub.dev/packages/basic_utils
[`charcode`]: https://pub.dev/packages/charcode
[`chunked_stream`]: https://pub.dev/packages/chunked_stream
[`circular_buffer`]: https://pub.dev/packages/circular_buffer
[`collection`]: https://pub.dev/packages/collection
[`convert`]: https://pub.dev/packages/convert
[`crypto`]: https://pub.dev/packages/crypto
[`csv`]: https://pub.dev/packages/csv
[`dart_console`]: https://pub.dev/packages/dart_console
[`dcli_core`]: https://pub.dev/packages/dcli_core
[`di_zone2`]: https://pub.dev/packages/di_zone2
[`equatable`]: https://pub.dev/packages/equatable
[`ffi`]: https://pub.dev/packages/ffi
[`file`]: https://pub.dev/packages/file
[`glob`]: https://pub.dev/packages/glob
[`http`]: https://pub.dev/packages/http
[`http_parser`]: https://pub.dev/packages/http_parser
[`ini`]: https://pub.dev/packages/ini
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
[`pubspec`]: https://pub.dev/packages/pubspec
[`quiver`]: https://pub.dev/packages/quiver
[`random_string`]: https://pub.dev/packages/random_string
[`settings_yaml`]: https://pub.dev/packages/settings_yaml
[`source_span`]: https://pub.dev/packages/source_span
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`stacktrace_impl`]: https://pub.dev/packages/stacktrace_impl
[`string_scanner`]: https://pub.dev/packages/string_scanner
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
