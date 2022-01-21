## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/example.dart`

## 20/20 Platform Support

### [*] 20/20 points: Supports 1 of 6 possible platforms (iOS, Android, **Web**, Windows, MacOS, Linux)

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

## 20/30 Pass static analysis

### [~] 20/30 points: code has no errors, warnings, lints, or formatting issues

Found 3 issues. Showing the first 2:

<details>
<summary>
INFO: Provide a deprecation message, via @Deprecated("message").
</summary>

`lib/src/draggable.dart:62:3`

```
   ╷
62 │   @deprecated
   │   ^^^^^^^^^^^
   ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/draggable.dart`
</details>
<details>
<summary>
INFO: Provide a deprecation message, via @Deprecated("message").
</summary>

`lib/src/draggable.dart:66:3`

```
   ╷
66 │   @deprecated
   │   ^^^^^^^^^^^
   ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/draggable.dart`
</details>

## 20/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

No dependencies.

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.


### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
