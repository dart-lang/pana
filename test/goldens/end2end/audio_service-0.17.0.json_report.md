## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/lib/main.dart`

## 20/20 Platform support

### [*] 20/20 points: Supports 4 of 6 possible platforms (**iOS**, **Android**, **Web**, Windows, **MacOS**, Linux)

* ✓ Android
* ✓ iOS
* ✓ MacOS
* ✓ Web

These platforms are not supported:

<details>
<summary>
Package does not support platform `Windows`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that declares support for platforms: `Android`, `iOS`, `macOS`, `Web`.
</details>
<details>
<summary>
Package does not support platform `Linux`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that declares support for platforms: `Android`, `iOS`, `macOS`, `Web`.
</details>

These issues are present but do not affect the score, because they may not originate in your package:

<details>
<summary>
Package does not support platform `macOS`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that imports:
* `package:flutter_isolate/flutter_isolate.dart` that declares support for platforms: `Android`, `iOS`.
</details>
<details>
<summary>
Package does not support platform `Web`.
</summary>

Because:
* `package:audio_service/audio_service.dart` that imports:
* `package:flutter_isolate/flutter_isolate.dart` that declares support for platforms: `Android`, `iOS`.
</details>

## 0/30 Pass static analysis

### [x] 0/30 points: code has no errors, warnings, lints, or formatting issues

<details>
<summary>
ERROR: The method 'setMockMethodCallHandler' isn't defined for the type 'MethodChannel'.
</summary>

`lib/audio_service.dart:674:16`

```
    ╷
674 │               .setMockMethodCallHandler(handler);
    │                ^^^^^^^^^^^^^^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/audio_service.dart`
</details>
<details>
<summary>
ERROR: The method 'setMockMethodCallHandler' isn't defined for the type 'MethodChannel'.
</summary>

`lib/audio_service.dart:1266:12`

```
     ╷
1266 │           .setMockMethodCallHandler(handler);
     │            ^^^^^^^^^^^^^^^^^^^^^^^^
     ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `flutter analyze lib/audio_service.dart`
</details>

## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Could not run `flutter pub outdated`: `dart pub get` failed:

```
OUT:
Resolving dependencies...
ERR:
Because audio_service requires the Flutter SDK, version solving failed.

Flutter users should run `flutter pub get` instead of `dart pub get`.
```

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
