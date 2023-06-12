## 20/30 Follow Dart file conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
The package description is too short.
</summary>

Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 characters to describe the package, what it does, and its target use case.
</details>

### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.

## 0/10 Provide documentation

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>

## 20/20 Platform support

### [*] 20/20 points: Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **MacOS**, **Linux**)

* ✓ Android
* ✓ iOS
* ✓ Windows
* ✓ Linux
* ✓ MacOS
* ✓ Web

## 0/30 Pass static analysis

### [x] 0/30 points: code has no errors, warnings, lints, or formatting issues

Found 10 issues. Showing the first 2:

<details>
<summary>
ERROR: The class 'List' doesn't have an unnamed constructor.
</summary>

`lib/src/parser.dart:100:33`

```
    ╷
100 │           location['invalid'] = List();
    │                                 ^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/parser.dart`
</details>
<details>
<summary>
ERROR: The constructor returns type 'List<dynamic>' that isn't of expected type 'List<String>'.
</summary>

`lib/src/parser.dart:140:24`

```
    ╷
140 │   List<String> parts = List();
    │                        ^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/src/parser.dart`
</details>

## 0/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

<details>
<summary>
Sdk constraint doesn't support current Dart version {{sdk-version}}. Cannot run `dart pub outdated`.
</summary>

`pubspec.yaml:10:8`

```
   ╷
10 │   sdk: '<3.0.0'
   │        ^^^^^^^^
   ╵
```

</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

<details>
<summary>
Sdk constraint doesn't support current Dart version {{sdk-version}}.
</summary>

`pubspec.yaml:10:8`

```
   ╷
10 │   sdk: '<3.0.0'
   │        ^^^^^^^^
   ╵
```

Try widening the upper boundary of the constraint.
</details>

## 0/20 Dart 3 compatibility

### [x] 0/20 points: Unable to detect Dart 3 compatibility

* Failed to analyze Dart 3 compatibilty:
```
Unable to run pub upgrade.
The lower bound of "sdk: '>=1.0.0 <3.0.0'" must be 2.12.0'
or higher to enable null safety.

The current Dart SDK (3.0.0) only supports null safety.

For details, see https://dart.dev/null-safety

```
