## 10/20 Follow Dart file conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

* Sdk-constraint doesn't allow future stable dart 2.x releases
<details>
<summary>
The package description is too short.
</summary>

Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 characters to describe the package, what it does, and its target use case.
</details>

### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 0/10 Provide documentation

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>

## 0/20 Support multiple platforms

### [x] 0/20 points: Supports 0 of 2 possible platforms (native, js)

<details>
<summary>
Package resolution failed. Could not determine platforms.
</summary>

Run `pub get` for more information.
</details>

## 0/30 Pass static analysis

### [x] 0/30 points: code has no errors, warnings, lints, or formatting issues

Found 59 issues. Showing the first 2:

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

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/skiplist.dart`
</details>
<details>
<summary>
ERROR: 'SkipList.[]' ('V Function(K)') isn't a valid override of 'Map.[]' ('V Function(Object)').
</summary>

`lib/skiplist.dart:77:14`

```
   ╷
77 │   V operator [](K key) {
   │              ^^
   ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/skiplist.dart`
</details>

## 0/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Sdk constraint doesn't support current Dart version 2.8.3. Cannot run `pub outdated`.

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

<details>
<summary>
Pubspec.yaml does not have an sdk version constraint.
</summary>

Try adding an sdk constraint to your pubspec.yaml
</details>
* Found no Flutter in your PATH. Could not determine the current Flutter version.