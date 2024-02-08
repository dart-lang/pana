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

* Running `dart pub outdated` failed with the following output:

```
The lower bound of "sdk: '>=1.0.0 <=3.2.5'" must be 2.12.0'
or higher to enable null safety.
```


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