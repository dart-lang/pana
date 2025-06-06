## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `BSD-3-Clause`.


## 10/20 Provide documentation

### [*] 10/10 points: 20% or more of the public API has dartdoc comments

246 out of 263 API elements (93.5 %) have documentation comments.

Some symbols that are missing documentation: `async.AsyncMemoizer.AsyncMemoizer.new`, `async.ChunkedStreamReader.ChunkedStreamReader.new`, `async.DelegatingFuture.DelegatingFuture.new`, `async.DelegatingStream.DelegatingStream.new`, `async.ErrorResult.ErrorResult.new`.

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>


## 20/20 Platform support

### [*] 20/20 points: Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **macOS**, **Linux**)

* ✓ Android

* ✓ iOS

* ✓ Windows

* ✓ Linux

* ✓ macOS

* ✓ Web

### [*] 0/0 points: WASM compatibility

This package is compatible with runtime `wasm`, and will be rewarded additional points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## 40/50 Pass static analysis

### [~] 40/50 points: code has no errors, warnings, lints, or formatting issues

<details>
<summary>
INFO: 'whereNotNull' is deprecated and shouldn't be used. Use .nonNulls instead.
</summary>

`lib/src/stream_group.dart:242:10`

```
    ╷
242 │         .whereNotNull()
    │          ^^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/stream_group.dart`
</details>


## 40/40 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|Notes|
|:-|:-|:-|:-|:-|
|[`collection`]|`^1.15.0`|1.19.1|1.19.1||
|[`meta`]|`^1.1.7`|1.17.0|1.17.0||

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`collection`]: https://pub.dev/packages/collection
[`meta`]: https://pub.dev/packages/meta

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.
