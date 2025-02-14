## 30/30 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`

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


## 0/20 Platform support

### [x] 0/20 points: Platform support detection failed

<details>
<summary>
Could not determine supported platforms as package resolution failed.
</summary>

Run `dart pub get` for more information.
</details>

### [x] 0/0 points: WASM compatibility

Unable to detect compatibility with runtime `wasm`, and this package will not be rewarded full points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## 0/50 Pass static analysis

### [x] 0/50 points: code has no errors, warnings, lints, or formatting issues

* Running `dart pub outdated` failed with the following output:

```
The lower bound of "sdk: '>=1.0.0 <3.0.0'" must be 2.12.0'
or higher to enable null safety.
```


## 0/40 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

<details>
<summary>
Sdk constraint doesn't support current Dart version {{sdk-version}}. Cannot run `dart pub outdated`.
</summary>

`pubspec.yaml:8:8`

```
  ╷
8 │   sdk: '>=1.0.0 <3.0.0'
  │        ^^^^^^^^^^^^^^^^
  ╵
```

</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

<details>
<summary>
Sdk constraint doesn't support current Dart version {{sdk-version}}.
</summary>

`pubspec.yaml:8:8`

```
  ╷
8 │   sdk: '>=1.0.0 <3.0.0'
  │        ^^^^^^^^^^^^^^^^
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
The lower bound of "sdk: '>=1.0.0 <3.0.0'" must be 2.12.0'
or higher to enable null safety.

The current Dart SDK (3.7.0) only supports null safety.

For details, see https://dart.dev/null-safety
```

Run `dart pub downgrade` and then `dart analyze` to reproduce the above problem.

You may run `dart pub upgrade --tighten` to update your dependency constraints, see [dart.dev/go/downgrade-testing](https://dart.dev/go/downgrade-testing) for details.
