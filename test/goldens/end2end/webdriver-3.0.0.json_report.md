## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


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

## 0/20 Support multiple platforms

### [x] 0/20 points: Supports 0 of 2 possible platforms (native, js)

SDK issues found:
<details>
<summary>
Package is not compatible with the Dart SDK.
</summary>

Because it is not compatible with any of the supported runtimes: `native-aot`, `native`, `js`.

Package is not compatible with Dart SDK using runtime `native-aot`. Because:
* `package:webdriver/async_html.dart` that imports:
* `package:webdriver/src/request/async_xhr_request_client.dart` that imports:
* `dart:html`

Package is not compatible with Dart SDK using runtime `native`. Because:
* `package:webdriver/async_html.dart` that imports:
* `package:webdriver/src/request/async_xhr_request_client.dart` that imports:
* `dart:html`

Package is not compatible with Dart SDK using runtime `js`. Because:
* `package:webdriver/async_io.dart` that imports:
* `package:webdriver/src/request/async_io_request_client.dart` that imports:
* `dart:io`
</details>

## 30/30 Pass static analysis

### [*] 30/30 points: code has no errors, warnings, lints, or formatting issues


## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`archive`]|`^3.0.0`|3.1.2|3.1.2|
|[`matcher`]|`^0.12.10`|0.12.10|0.12.10|
|[`path`]|`^1.8.0`|1.8.0|1.8.0|
|[`stack_trace`]|`^1.10.0`|1.10.0|1.10.0|
|[`sync_http`]|`^0.3.0`|0.3.0|0.3.0|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`collection`]|-|1.15.0|1.15.0|
|[`crypto`]|-|3.0.1|3.0.1|
|[`typed_data`]|-|1.3.0|1.3.0|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`archive`]: https://pub.dev/packages/archive
[`matcher`]: https://pub.dev/packages/matcher
[`path`]: https://pub.dev/packages/path
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`sync_http`]: https://pub.dev/packages/sync_http
[`collection`]: https://pub.dev/packages/collection
[`crypto`]: https://pub.dev/packages/crypto
[`typed_data`]: https://pub.dev/packages/typed_data


### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
