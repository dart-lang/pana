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

## 0/20 Platform support

### [x] 0/20 points: Supports 0 of 6 possible platforms (iOS, Android, Web, Windows, MacOS, Linux)


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

## 20/30 Pass static analysis

### [~] 20/30 points: code has no errors, warnings, lints, or formatting issues

Found 15 issues. Showing the first 2:

<details>
<summary>
INFO: Provide a deprecation message, via @Deprecated("message").
</summary>

`lib/src/async/web_driver.dart:139:3`

```
    ╷
139 │   @deprecated
    │   ^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/async/web_driver.dart`
</details>
<details>
<summary>
INFO: Provide a deprecation message, via @Deprecated("message").
</summary>

`lib/src/async/web_element.dart:135:3`

```
    ╷
135 │   @deprecated
    │   ^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/async/web_element.dart`
</details>

## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`archive`]|`^3.0.0`|3.3.1|3.3.1|
|[`matcher`]|`^0.12.10`|0.12.12|0.12.12|
|[`path`]|`^1.8.0`|1.8.2|1.8.2|
|[`stack_trace`]|`^1.10.0`|1.10.0|1.10.0|
|[`sync_http`]|`^0.3.0`|0.3.1|0.3.1|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`collection`]|-|1.16.0|1.16.0|
|[`crypto`]|-|3.0.2|3.0.2|
|[`typed_data`]|-|1.3.1|1.3.1|
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
