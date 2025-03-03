## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example


## 20/20 Platform support

### [*] 20/20 points: Supports 5 of 6 possible platforms (**iOS**, **Android**, Web, **Windows**, **macOS**, **Linux**)

* ✓ Android

* ✓ iOS

* ✓ Windows

* ✓ Linux

* ✓ macOS


These platforms are not supported:

<details>
<summary>
Package not compatible with platform Web
</summary>

Because:
* `package:gg/gg.dart` that imports:
* `package:gg/src/tools/checks.dart` that imports:
* `package:gg_publish/gg_publish.dart` that imports:
* `package:gg_publish/src/commands/publish.dart` that imports:
* `package:gg_version/gg_version.dart` that imports:
* `package:gg_version/src/commands/published_version.dart` that imports:
* `package:gg_args/gg_args.dart` that imports:
* `package:gg_args/src/missing_sub_commands.dart` that imports:
* `dart:io`
</details>

### [x] 0/0 points: WASM compatibility

<details>
<summary>
Package not compatible with runtime wasm
</summary>

Because:
* `package:gg/gg.dart` that imports:
* `package:gg/src/tools/checks.dart` that imports:
* `package:gg_publish/gg_publish.dart` that imports:
* `package:gg_publish/src/commands/publish.dart` that imports:
* `package:gg_version/gg_version.dart` that imports:
* `package:gg_version/src/commands/published_version.dart` that imports:
* `package:gg_args/gg_args.dart` that imports:
* `package:gg_args/src/missing_sub_commands.dart` that imports:
* `dart:io`
</details>

This package is not compatible with runtime `wasm`, and will not be rewarded full points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## 50/50 Pass static analysis

### [*] 50/50 points: code has no errors, warnings, lints, or formatting issues


## 10/40 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`args`]|`^2.4.2`|2.6.0|2.6.0|
|[`gg_args`]|`^1.1.10`|1.1.17|**2.0.4**|
|[`gg_console_colors`]|`^2.0.1`|2.1.4|2.1.4|
|[`gg_git`]|`^2.0.0`|2.5.9|2.5.16|
|[`gg_is_flutter`]|`^1.0.3`|1.0.5|1.0.7|
|[`gg_json`]|`^1.0.0`|1.0.6|**2.0.2**|
|[`gg_log`]|`^1.0.0`|1.0.6|1.0.6|
|[`gg_process`]|`^1.0.6`|1.1.6|1.1.6|
|[`gg_publish`]|`^2.0.0`|2.0.1|**3.0.16**|
|[`gg_status_printer`]|`^1.1.0`|1.1.4|1.1.4|
|[`gg_test`]|`^1.0.3`|1.0.11|1.1.3|
|[`gg_version`]|`^1.0.0`|1.3.1|**4.0.3**|
|[`meta`]|`^1.12.0`|1.16.0|1.16.0|
|[`mocktail`]|`^1.0.3`|1.0.4|1.0.4|
|[`path`]|`^1.8.0`|1.9.1|1.9.1|
|[`pub_semver`]|`^2.1.4`|2.1.5|2.1.5|
|[`recase`]|`^4.1.0`|4.1.0|4.1.0|
|[`yaml`]|`^3.1.2`|3.1.3|3.1.3|
|[`yaml_edit`]|`^2.2.0`|2.2.2|2.2.2|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`async`]|-|2.13.0|2.13.0|
|[`boolean_selector`]|-|2.1.2|2.1.2|
|[`checked_yaml`]|-|2.0.3|2.0.3|
|[`collection`]|-|1.19.1|1.19.1|
|[`colorize`]|-|3.0.0|3.0.0|
|[`gg_capture_print`]|-|1.0.9|1.0.9|
|[`gg_hash`]|-|1.0.4|1.0.4|
|[`gg_is_github`]|-|1.0.6|1.0.6|
|[`gg_project_root`]|-|1.0.2|1.0.4|
|[`http`]|-|1.3.0|1.3.0|
|[`http_parser`]|-|4.1.2|4.1.2|
|[`json_annotation`]|-|4.9.0|4.9.0|
|[`matcher`]|-|0.12.17|0.12.17|
|[`pubspec_parse`]|-|1.5.0|1.5.0|
|[`source_span`]|-|1.10.1|1.10.1|
|[`stack_trace`]|-|1.12.1|1.12.1|
|[`stream_channel`]|-|2.1.4|2.1.4|
|[`string_scanner`]|-|1.4.1|1.4.1|
|[`term_glyph`]|-|1.2.2|1.2.2|
|[`test_api`]|-|0.7.4|0.7.4|
|[`typed_data`]|-|1.4.0|1.4.0|
|[`web`]|-|1.1.0|1.1.0|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`args`]: https://pub.dev/packages/args
[`gg_args`]: https://pub.dev/packages/gg_args
[`gg_console_colors`]: https://pub.dev/packages/gg_console_colors
[`gg_git`]: https://pub.dev/packages/gg_git
[`gg_is_flutter`]: https://pub.dev/packages/gg_is_flutter
[`gg_json`]: https://pub.dev/packages/gg_json
[`gg_log`]: https://pub.dev/packages/gg_log
[`gg_process`]: https://pub.dev/packages/gg_process
[`gg_publish`]: https://pub.dev/packages/gg_publish
[`gg_status_printer`]: https://pub.dev/packages/gg_status_printer
[`gg_test`]: https://pub.dev/packages/gg_test
[`gg_version`]: https://pub.dev/packages/gg_version
[`meta`]: https://pub.dev/packages/meta
[`mocktail`]: https://pub.dev/packages/mocktail
[`path`]: https://pub.dev/packages/path
[`pub_semver`]: https://pub.dev/packages/pub_semver
[`recase`]: https://pub.dev/packages/recase
[`yaml`]: https://pub.dev/packages/yaml
[`yaml_edit`]: https://pub.dev/packages/yaml_edit
[`async`]: https://pub.dev/packages/async
[`boolean_selector`]: https://pub.dev/packages/boolean_selector
[`checked_yaml`]: https://pub.dev/packages/checked_yaml
[`collection`]: https://pub.dev/packages/collection
[`colorize`]: https://pub.dev/packages/colorize
[`gg_capture_print`]: https://pub.dev/packages/gg_capture_print
[`gg_hash`]: https://pub.dev/packages/gg_hash
[`gg_is_github`]: https://pub.dev/packages/gg_is_github
[`gg_project_root`]: https://pub.dev/packages/gg_project_root
[`http`]: https://pub.dev/packages/http
[`http_parser`]: https://pub.dev/packages/http_parser
[`json_annotation`]: https://pub.dev/packages/json_annotation
[`matcher`]: https://pub.dev/packages/matcher
[`pubspec_parse`]: https://pub.dev/packages/pubspec_parse
[`source_span`]: https://pub.dev/packages/source_span
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`stream_channel`]: https://pub.dev/packages/stream_channel
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`test_api`]: https://pub.dev/packages/test_api
[`typed_data`]: https://pub.dev/packages/typed_data
[`web`]: https://pub.dev/packages/web

Found 4 issues. Showing the first 2:

<details>
<summary>
The constraint `^1.1.10` on gg_args does not support the stable version `2.0.0`.
</summary>

Try running `dart pub upgrade --major-versions gg_args` to update the constraint.
</details>

<details>
<summary>
The constraint `^1.0.0` on gg_json does not support the stable version `2.0.0`.
</summary>

Try running `dart pub upgrade --major-versions gg_json` to update the constraint.
</details>

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [x] 0/20 points: Compatible with dependency constraint lower bounds

downgrade analysis failed failed with 10 errors:

 - `UNDEFINED_CLASS` - `lib/src/commands/can/can_publish.dart:21:5` - Undefined class 'IsVersionPrepared'.
 - `UNDEFINED_METHOD` - `lib/src/commands/can/can_publish.dart:25:34` - The method 'IsVersionPrepared' isn't defined for the type 'CanPublish'.
 - `UNDEFINED_METHOD` - `lib/src/commands/check/analyze.dart:48:12` - The method 'ErrorInfoReader' isn't defined for the type 'Analyze'.

Run `dart pub downgrade` and then `dart analyze` to reproduce the above problem.

You may run `dart pub upgrade --tighten` to update your dependency constraints, see [dart.dev/go/downgrade-testing](https://dart.dev/go/downgrade-testing) for details.
