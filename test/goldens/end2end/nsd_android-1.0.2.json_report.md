## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/EXAMPLE.md`

## 20/20 Platform support

### [*] 20/20 points: Supports 1 of 6 possible platforms (iOS, **Android**, Web, Windows, MacOS, Linux)

* ✓ Android

These platforms are not supported:

<details>
<summary>
Package does not support platform `iOS`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>
<details>
<summary>
Package does not support platform `Windows`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>
<details>
<summary>
Package does not support platform `Linux`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>
<details>
<summary>
Package does not support platform `macOS`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>
<details>
<summary>
Package does not support platform `Web`.
</summary>

Because:
* `nsd_android` that declares support for platforms: `Android`.
</details>

## 30/30 Pass static analysis

### [*] 30/30 points: code has no errors, warnings, lints, or formatting issues


## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Could not run `flutter pub outdated`: `dart pub get` failed:

```
OUT:
Resolving dependencies...
ERR:
Because nsd_android requires the Flutter SDK, version solving failed.

Flutter users should run `flutter pub get` instead of `dart pub get`.
```

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
