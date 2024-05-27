## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.

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

## 0/50 Pass static analysis

### [x] 0/50 points: code has no errors, warnings, lints, or formatting issues

* Running `flutter pub outdated` failed with the following output:

```
Note: meta is pinned to version 1.12.0 by flutter_web_plugins from the flutter SDK.
See https://dart.dev/go/sdk-version-pinning for details.
```


## 10/40 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Could not run `flutter pub outdated`: `flutter pub get` failed:

```
OUT:
Resolving dependencies...
ERR:
Note: meta is pinned to version 1.12.0 by flutter_web_plugins from the flutter SDK.
See https://dart.dev/go/sdk-version-pinning for details.


Because every version of flutter_web_plugins from sdk depends on meta 1.12.0 which doesn't match any versions, flutter_web_plugins from sdk is forbidden.
So, because audio_service depends on flutter_web_plugins from sdk, version solving failed.
```

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


### [x] 0/20 points: Compatible with dependency constraint lower bounds

* `flutter pub downgrade` failed with:

```
OUT:
Resolving dependencies...
ERR:
Note: meta is pinned to version 1.12.0 by flutter_web_plugins from the flutter SDK.
See https://dart.dev/go/sdk-version-pinning for details.


Because every version of flutter_web_plugins from sdk depends on meta 1.12.0 which doesn't match any versions, flutter_web_plugins from sdk is forbidden.
So, because audio_service depends on flutter_web_plugins from sdk, version solving failed.
```

Run `flutter pub downgrade` and then `flutter analyze` to reproduce the above problem.

You may run `dart pub upgrade --tighten` to update your dependency constraints, see [dart.dev/go/downgrade-testing](https://dart.dev/go/downgrade-testing) for details.