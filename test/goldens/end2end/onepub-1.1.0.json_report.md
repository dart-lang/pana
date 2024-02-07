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

`pubspec.yaml` from the repository URL mismatch: expected `https://github.com/noojee/onepub.dev` but got `https://github.com/onepub-dev/onepub`.
</details>

### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


### [x] 0/10 points: Use an OSI-approved license

<details>
<summary>
No license was recognized.
</summary>

Consider using an [OSI-approved license](https://opensource.org/licenses) in the `LICENSE` file to make it more accessible to the community.
</details>

## 10/20 Provide documentation

### [*] 10/10 points: 20% or more of the public API has dartdoc comments

0 out of 0 API elements (100.0 %) have documentation comments.

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>

## 20/20 Platform support

### [*] 20/20 points: Supports 3 of 6 possible platforms (iOS, Android, Web, **Windows**, **macOS**, **Linux**)

* ✓ Linux
* ✓ macOS
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

## 50/50 Pass static analysis

### [*] 50/50 points: code has no errors, warnings, lints, or formatting issues


## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`dcli`]|`^1.15.5`|1.36.2|**3.1.0**|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`archive`]|-|3.4.6|3.4.6|
|[`args`]|-|2.4.2|2.4.2|
|[`async`]|-|2.11.0|2.11.0|
|[`basic_utils`]|-|3.9.4|5.7.0|
|[`boolean_selector`]|-|2.1.1|2.1.1|
|[`characters`]|-|1.3.0|1.3.0|
|[`chunked_stream`]|-|1.4.2|1.4.2|
|[`circular_buffer`]|-|0.11.0|0.11.0|
|[`clock`]|-|1.1.1|1.1.1|
|[`collection`]|-|1.18.0|1.18.0|
|[`convert`]|-|3.1.1|3.1.1|
|[`crypto`]|-|3.0.3|3.0.3|
|[`csv`]|-|5.1.0|5.1.0|
|[`dart_console2`]|-|2.0.1|3.0.0|
|[`dcli_core`]|-|1.36.2|3.1.0|
|[`equatable`]|-|2.0.5|2.0.5|
|[`ffi`]|-|2.1.0|2.1.0|
|[`file`]|-|6.1.4|7.0.0|
|[`file_utils`]|-|1.0.1|1.0.1|
|[`functional_data`]|-|1.1.1|1.1.1|
|[`glob`]|-|2.1.2|2.1.2|
|[`globbing`]|-|1.0.0|1.0.0|
|[`http`]|-|0.13.6|1.1.0|
|[`http_parser`]|-|4.0.2|4.0.2|
|[`ini`]|-|2.1.0|2.1.0|
|[`intl`]|-|0.17.0|0.18.1|
|[`js`]|-|0.6.7|0.6.7|
|[`json2yaml`]|-|3.0.1|3.0.1|
|[`json_annotation`]|-|4.8.1|4.8.1|
|[`logging`]|-|1.2.0|1.2.0|
|[`matcher`]|-|0.12.16|0.12.16|
|[`meta`]|-|1.11.0|1.11.0|
|[`mime`]|-|1.0.4|1.0.4|
|[`path`]|-|1.8.3|1.8.3|
|[`pointycastle`]|-|3.7.3|3.7.3|
|[`posix`]|-|4.1.0|5.0.0|
|[`pub_semver`]|-|2.1.4|2.1.4|
|[`pubspec2`]|-|2.4.2|4.0.0|
|[`pubspec_lock`]|-|3.0.2|3.0.2|
|[`quiver`]|-|3.2.1|3.2.1|
|[`random_string`]|-|2.3.1|2.3.1|
|[`scope`]|-|3.0.0|4.1.0|
|[`settings_yaml`]|-|4.0.1|7.1.0|
|[`source_span`]|-|1.10.0|1.10.0|
|[`stack_trace`]|-|1.11.1|1.11.1|
|[`stacktrace_impl`]|-|2.3.0|2.3.0|
|[`stream_channel`]|-|2.1.2|2.1.2|
|[`string_scanner`]|-|1.2.0|1.2.0|
|[`sum_types`]|-|0.3.5|0.3.5|
|[`system_info2`]|-|2.0.4|4.0.0|
|[`term_glyph`]|-|1.2.1|1.2.1|
|[`test_api`]|-|0.6.1|0.6.1|
|[`typed_data`]|-|1.3.2|1.3.2|
|[`uuid`]|-|3.0.7|4.1.0|
|[`validators2`]|-|3.0.0|5.0.0|
|[`vin_decoder`]|-|0.2.1-nullsafety|0.2.1-nullsafety|
|[`win32`]|-|3.1.4|5.0.9|
|[`yaml`]|-|3.1.2|3.1.2|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`dcli`]: https://pub.dev/packages/dcli
[`archive`]: https://pub.dev/packages/archive
[`args`]: https://pub.dev/packages/args
[`async`]: https://pub.dev/packages/async
[`basic_utils`]: https://pub.dev/packages/basic_utils
[`boolean_selector`]: https://pub.dev/packages/boolean_selector
[`characters`]: https://pub.dev/packages/characters
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
[`functional_data`]: https://pub.dev/packages/functional_data
[`glob`]: https://pub.dev/packages/glob
[`globbing`]: https://pub.dev/packages/globbing
[`http`]: https://pub.dev/packages/http
[`http_parser`]: https://pub.dev/packages/http_parser
[`ini`]: https://pub.dev/packages/ini
[`intl`]: https://pub.dev/packages/intl
[`js`]: https://pub.dev/packages/js
[`json2yaml`]: https://pub.dev/packages/json2yaml
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
[`pubspec_lock`]: https://pub.dev/packages/pubspec_lock
[`quiver`]: https://pub.dev/packages/quiver
[`random_string`]: https://pub.dev/packages/random_string
[`scope`]: https://pub.dev/packages/scope
[`settings_yaml`]: https://pub.dev/packages/settings_yaml
[`source_span`]: https://pub.dev/packages/source_span
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`stacktrace_impl`]: https://pub.dev/packages/stacktrace_impl
[`stream_channel`]: https://pub.dev/packages/stream_channel
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`sum_types`]: https://pub.dev/packages/sum_types
[`system_info2`]: https://pub.dev/packages/system_info2
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`test_api`]: https://pub.dev/packages/test_api
[`typed_data`]: https://pub.dev/packages/typed_data
[`uuid`]: https://pub.dev/packages/uuid
[`validators2`]: https://pub.dev/packages/validators2
[`vin_decoder`]: https://pub.dev/packages/vin_decoder
[`win32`]: https://pub.dev/packages/win32
[`yaml`]: https://pub.dev/packages/yaml

<details>
<summary>
The constraint `^1.15.5` on dcli does not support the stable version `2.0.1`.
</summary>

Try running `dart pub upgrade --major-versions dcli` to update the constraint.
</details>

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs
