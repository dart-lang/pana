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

## 0/20 Platform support

### [x] 0/20 points: Platform support detection failed

<details>
<summary>
Could not determine supported platforms as package resolution failed.
</summary>

Run `dart pub get` for more information.
</details>

## 0/50 Pass static analysis

### [x] 0/50 points: code has no errors, warnings, lints, or formatting issues

Found 37 issues. Showing the first 2:

<details>
<summary>
ERROR: Target of URI doesn't exist: 'package:quiver_iterables/iterables.dart'.
</summary>

`lib/skiplist.dart:12:8`

```
   ╷
12 │ import "package:quiver_iterables/iterables.dart" as iterables;
   │        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/skiplist.dart`
</details>
<details>
<summary>
ERROR: Non-nullable instance field '_header' must be initialized.
</summary>

`lib/skiplist.dart:48:3`

```
   ╷
48 │   SkipList({double this.p: 1 / 4, int this.maxLevel: 8}) {
   │   ^^^^^^^^
   ╵
```

To reproduce make sure you are using the [lints_core](https://pub.dev/packages/lints) and run `dart analyze lib/skiplist.dart`
</details>

## 0/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Sdk constraint doesn't support current Dart version {{sdk-version}}. Cannot run `dart pub outdated`.

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

<details>
<summary>
Pubspec.yaml does not have an sdk version constraint.
</summary>

Try adding an sdk constraint to your `pubspec.yaml`
</details>