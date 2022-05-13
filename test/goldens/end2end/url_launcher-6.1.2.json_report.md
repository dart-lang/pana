## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example


## 0/20 Platform support

### [x] 0/20 points: Platform support detection failed

<details>
<summary>
Could not determine supported platforms as package resolution failed.
</summary>

Run `flutter pub get` for more information.
</details>

## 0/30 Pass static analysis

### [x] 0/30 points: code has no errors, warnings, lints, or formatting issues

Found 78 issues. Showing the first 2:

<details>
<summary>
ERROR: Target of URI doesn't exist: 'package:url_launcher_platform_interface/link.dart'.
</summary>

`lib/link.dart:5:8`

```
  ╷
5 │ export 'package:url_launcher_platform_interface/link.dart'
  │        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/link.dart`
</details>
<details>
<summary>
ERROR: Target of URI doesn't exist: 'package:flutter/foundation.dart'.
</summary>

`lib/src/legacy_api.dart:7:8`

```
  ╷
7 │ import 'package:flutter/foundation.dart';
  │        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/src/legacy_api.dart`
</details>

## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Could not run `flutter pub outdated`: `dart pub get` failed:

```
OUT:
Resolving dependencies...
ERR:
Because every version of flutter_test from sdk depends on vector_math 2.1.2 which doesn't match any versions, flutter_test from sdk is forbidden.
So, because url_launcher depends on flutter_test from sdk, version solving failed.
```

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 0/20 Support sound null safety

### [x] 0/20 points: Unable to detect null safety

<details>
<summary>
Package resolution failed. Could not determine null safety.
</summary>

Run `dart pub get` for more information.
</details>