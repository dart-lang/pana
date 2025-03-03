## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `Apache-2.0`.


## 0/10 Provide documentation

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>


## 0/20 Platform support

### [x] 0/20 points: Supports 0 of 6 possible platforms (iOS, Android, Web, Windows, macOS, Linux)


These platforms are not supported:

<details>
<summary>
Package not compatible with platform Android
</summary>

Because:
* `package:webdriver/async_html.dart` that imports:
* `package:webdriver/src/request/async_xhr_request_client.dart` that imports:
* `dart:html`
</details>

<details>
<summary>
Package not compatible with platform iOS
</summary>

Because:
* `package:webdriver/async_html.dart` that imports:
* `package:webdriver/src/request/async_xhr_request_client.dart` that imports:
* `dart:html`
</details>

<details>
<summary>
Package not compatible with platform Windows
</summary>

Because:
* `package:webdriver/async_html.dart` that imports:
* `package:webdriver/src/request/async_xhr_request_client.dart` that imports:
* `dart:html`
</details>

<details>
<summary>
Package not compatible with platform Linux
</summary>

Because:
* `package:webdriver/async_html.dart` that imports:
* `package:webdriver/src/request/async_xhr_request_client.dart` that imports:
* `dart:html`
</details>

<details>
<summary>
Package not compatible with platform macOS
</summary>

Because:
* `package:webdriver/async_html.dart` that imports:
* `package:webdriver/src/request/async_xhr_request_client.dart` that imports:
* `dart:html`
</details>

<details>
<summary>
Package not compatible with platform Web
</summary>

Because:
* `package:webdriver/async_io.dart` that imports:
* `package:webdriver/src/request/async_io_request_client.dart` that imports:
* `dart:io`
</details>

### [x] 0/0 points: WASM compatibility

<details>
<summary>
Package not compatible with runtime wasm
</summary>

Because:
* `package:webdriver/async_html.dart` that imports:
* `package:webdriver/src/request/async_xhr_request_client.dart` that imports:
* `dart:html`
</details>

This package is not compatible with runtime `wasm`, and will not be rewarded full points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## 30/50 Pass static analysis

### [x] 30/50 points: code has no errors, warnings, lints, or formatting issues

Found 19 issues. Showing the first 2:

<details>
<summary>
WARNING: Unnecessary type check; the result is always 'true'.
</summary>

`lib/src/async/web_element.dart:154:7`

```
    ╷
154 │       other is WebElement && other.driver == driver && other.id == id;
    │       ^^^^^^^^^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/async/web_element.dart`
</details>

<details>
<summary>
WARNING: Unnecessary type check; the result is always 'true'.
</summary>

`lib/src/handler/json_wire/utils.dart:26:8`

```
   ╷
26 │       (responseBody is Map &&
   │        ^^^^^^^^^^^^^^^^^^^
   ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/handler/json_wire/utils.dart`
</details>


## 30/40 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`archive`]|`^3.0.0`|3.6.1|**4.0.2**|
|[`matcher`]|`^0.12.10`|0.12.17|0.12.17|
|[`path`]|`^1.8.0`|1.9.1|1.9.1|
|[`stack_trace`]|`^1.10.0`|1.12.1|1.12.1|
|[`sync_http`]|`^0.3.0`|0.3.1|0.3.1|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`async`]|-|2.13.0|2.13.0|
|[`boolean_selector`]|-|2.1.2|2.1.2|
|[`collection`]|-|1.19.1|1.19.1|
|[`crypto`]|-|3.0.6|3.0.6|
|[`meta`]|-|1.16.0|1.16.0|
|[`source_span`]|-|1.10.1|1.10.1|
|[`stream_channel`]|-|2.1.4|2.1.4|
|[`string_scanner`]|-|1.4.1|1.4.1|
|[`term_glyph`]|-|1.2.2|1.2.2|
|[`test_api`]|-|0.7.4|0.7.4|
|[`typed_data`]|-|1.4.0|1.4.0|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`archive`]: https://pub.dev/packages/archive
[`matcher`]: https://pub.dev/packages/matcher
[`path`]: https://pub.dev/packages/path
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`sync_http`]: https://pub.dev/packages/sync_http
[`async`]: https://pub.dev/packages/async
[`boolean_selector`]: https://pub.dev/packages/boolean_selector
[`collection`]: https://pub.dev/packages/collection
[`crypto`]: https://pub.dev/packages/crypto
[`meta`]: https://pub.dev/packages/meta
[`source_span`]: https://pub.dev/packages/source_span
[`stream_channel`]: https://pub.dev/packages/stream_channel
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`test_api`]: https://pub.dev/packages/test_api
[`typed_data`]: https://pub.dev/packages/typed_data

<details>
<summary>
The constraint `^3.0.0` on archive does not support the stable version `4.0.0`.
</summary>

Try running `dart pub upgrade --major-versions archive` to update the constraint.
</details>

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.
