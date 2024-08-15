## 15/30 Follow Dart file conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
Sdk-constraint doesn't allow future stable dart 2.x releases
</summary>

`pubspec.yaml:6:8`

```
  ╷
6 │   sdk: ">=2.12.0-0 <2.12.0"
  │        ^^^^^^^^^^^^^^^^^^^^
  ╵
```

</details>
<details>
<summary>
The package description is too short.
</summary>

Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 characters to describe the package, what it does, and its target use case.
</details>
<details>
<summary>
Failed to verify repository URL.
</summary>

Please provide a valid [`repository`](https://dart.dev/tools/pub/pubspec#repository) URL in `pubspec.yaml`, such that:

 * `repository` can be cloned,
 * a clone of the repository contains a `pubspec.yaml`, which:,
    * contains `name: _dummy_pkg`,
    * contains a `version` property, and,
    * does not contain a `publish_to` property.

`pkg/pub_integration/test_data/_dummy_pkg/pubspec.yaml` from the repository has no `version`.
</details>

### [*] 5/5 points: Provide a valid `README.md`


### [x] 0/5 points: Provide a valid `CHANGELOG.md`

<details>
<summary>
No `CHANGELOG.md` found.
</summary>

Changelog entries help developers follow the progress of your package. Check out the Dart conventions for [Maintaining a package changelog](https://dart.dev/tools/pub/package-layout#changelog).
</details>

### [*] 10/10 points: Use an OSI-approved license

Detected license: `BSD-3-Clause`.

## 10/20 Provide documentation

### [x] 0/10 points: 20% or more of the public API has dartdoc comments

Dependency resolution failed, unable to run `dartdoc`.

### [*] 10/10 points: Package has an example


## 0/20 Platform support

### [x] 0/20 points: Platform support detection failed

<details>
<summary>
Could not determine supported platforms as package resolution failed.
</summary>

Run `dart pub get` for more information.
</details>

### [x] 0/0 points: WASM readiness

Unable to detect compatibility with runtime `wasm`.

## 0/50 Pass static analysis

### [x] 0/50 points: code has no errors, warnings, lints, or formatting issues

* Running `dart pub outdated` failed with the following output:

```
The current Dart SDK version is {{sdk-version}}.
Because _dummy_pkg requires SDK version >=2.12.0-0 <2.12.0, version solving failed.
```


## 0/40 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

<details>
<summary>
Sdk constraint doesn't support current Dart version {{sdk-version}}. Cannot run `dart pub outdated`.
</summary>

`pubspec.yaml:6:8`

```
  ╷
6 │   sdk: ">=2.12.0-0 <2.12.0"
  │        ^^^^^^^^^^^^^^^^^^^^
  ╵
```

</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

<details>
<summary>
Sdk constraint doesn't support current Dart version {{sdk-version}}.
</summary>

`pubspec.yaml:6:8`

```
  ╷
6 │   sdk: ">=2.12.0-0 <2.12.0"
  │        ^^^^^^^^^^^^^^^^^^^^
  ╵
```

Try widening the upper boundary of the constraint.
</details>

### [x] 0/20 points: Compatible with dependency constraint lower bounds

`dart pub downgrade` failed with:

```
OUT:
Resolving dependencies...
ERR:
The current Dart SDK version is {{sdk-version}}.

Because _dummy_pkg requires SDK version >=2.12.0-0 <2.12.0, version solving failed.
```

Run `dart pub downgrade` and then `dart analyze` to reproduce the above problem.

You may run `dart pub upgrade --tighten` to update your dependency constraints, see [dart.dev/go/downgrade-testing](https://dart.dev/go/downgrade-testing) for details.