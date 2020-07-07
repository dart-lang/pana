## 10/20 Packaging conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
Sdk-constraint doesn't allow future stable dart 2.x releases
</summary>

`pubspec.yaml:8:8`

```
  ╷
8 │   sdk: '>=1.24.0 <2.0.0'
  │        ^^^^^^^^^^^^^^^^^
  ╵
```

</details>

### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 0/10 Package has documentation

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>

## 0/20 Package is multi-platform

### [x] 0/20 points: Supports 0 of 2 possible platforms (native, js)

<details>
<summary>
Package resolution failed. Could not determine platforms.
</summary>

Run `pub get` for more information.
</details>

## 0/20 Code follows recommended code style

### [x] 0/20 points: code has no errors, warnings, lints, or formatting issues

Found 621 issues. Showing the first 2:

<details>
<summary>
ERROR: Target of URI doesn't exist: 'package:path/path.dart'.
</summary>

`lib/fs.dart:12:8`

```
   ╷
12 │ import 'package:path/path.dart';
   │        ^^^^^^^^^^^^^^^^^^^^^^^^
   ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/fs.dart`
</details>
<details>
<summary>
ERROR: The default value of an optional parameter must be constant.
</summary>

`lib/fs.dart:179:58`

```
    ╷
179 │       {FileMode mode: FileMode.WRITE, Encoding encoding: UTF8});
    │                                                          ^^^^
    ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/fs.dart`
</details>

## 10/30 Package is a good, trustworthy dependency

### [x] 0/10 points: All of the package dependencies are supported in the latest version

<details>
<summary>
Sdk constraint doesn't support current Dart version 2.8.3. Cannot run `pub outdated`.
</summary>

`pubspec.yaml:8:8`

```
  ╷
8 │   sdk: '>=1.24.0 <2.0.0'
  │        ^^^^^^^^^^^^^^^^^
  ╵
```

</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

<details>
<summary>
The current sdk constraint does not allow the latest stable Dart (2.8.3)
</summary>

`pubspec.yaml:8:8`

```
  ╷
8 │   sdk: '>=1.24.0 <2.0.0'
  │        ^^^^^^^^^^^^^^^^^
  ╵
```

Try widening the upper boundary of the constraint.
</details>
* Found no Flutter in your PATH. Could not determine the current Flutter version.

### [*] 10/10 points: Package is published using a verified publisher
