## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.


## 20/20 Provide documentation

### [*] 10/10 points: 20% or more of the public API has dartdoc comments

70 out of 72 API elements (97.2 %) have documentation comments.

Some symbols that are missing documentation: `dnd`, `dnd.DraggablesAcceptor.draggableIds`.

### [*] 10/10 points: Package has an example


## 20/20 Platform support

### [*] 20/20 points: Supports 1 of 6 possible platforms (iOS, Android, **Web**, Windows, macOS, Linux)

* ✓ Web


These platforms are not supported:

<details>
<summary>
Package not compatible with platform Android
</summary>

Because:
* `package:dnd/dnd.dart` that imports:
* `dart:js`
</details>

<details>
<summary>
Package not compatible with platform iOS
</summary>

Because:
* `package:dnd/dnd.dart` that imports:
* `dart:js`
</details>

<details>
<summary>
Package not compatible with platform Windows
</summary>

Because:
* `package:dnd/dnd.dart` that imports:
* `dart:js`
</details>

<details>
<summary>
Package not compatible with platform Linux
</summary>

Because:
* `package:dnd/dnd.dart` that imports:
* `dart:js`
</details>

<details>
<summary>
Package not compatible with platform macOS
</summary>

Because:
* `package:dnd/dnd.dart` that imports:
* `dart:js`
</details>

### [x] 0/0 points: WASM compatibility

<details>
<summary>
Package not compatible with runtime wasm
</summary>

Because:
* `package:dnd/dnd.dart` that imports:
* `dart:js`
</details>

This package is not compatible with runtime `wasm`, and will not be rewarded full points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## 30/50 Pass static analysis

### [x] 30/50 points: code has no errors, warnings, lints, or formatting issues

Found 11 issues. Showing the first 2:

<details>
<summary>
WARNING: Unnecessary type check; the result is always 'true'.
</summary>

`lib/src/draggable_manager.dart:183:9`

```
    ╷
183 │     if (target is Element &&
    │         ^^^^^^^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/draggable_manager.dart`
</details>

<details>
<summary>
INFO: 'dart:html' is deprecated and shouldn't be used. Use package:web and dart:js_interop instead.
</summary>

`lib/dnd.dart:3:1`

```
  ╷
3 │ import 'dart:html';
  │ ^^^^^^^^^^^^^^^^^^^
  ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/dnd.dart`
</details>


## 40/40 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

No dependencies.

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.
