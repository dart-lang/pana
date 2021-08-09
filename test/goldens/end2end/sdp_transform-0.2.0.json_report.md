## 10/20 Follow Dart file conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

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

## 20/20 Support multiple platforms

### [*] 20/20 points: Supports 2 of 2 possible platforms (**native**, **js**)


## 20/30 Pass static analysis

### [~] 20/30 points: code has no errors, warnings, lints, or formatting issues

<details>
<summary>
lib/src/grammar.dart doesn't match the Dart formatter.
</summary>

To format your files run: `dart format .`
</details>
<details>
<summary>
lib/src/parser.dart doesn't match the Dart formatter.
</summary>

To format your files run: `dart format .`
</details>

## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Could not run `dart pub outdated`: `dart pub get` failed: 

 ```
pubspec.yaml has no lower-bound SDK constraint.
You should edit pubspec.yaml to contain an SDK constraint:

environment:
  sdk: '>=2.10.0 <3.0.0'

See https://dart.dev/go/sdk-constraint

```

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 0/20 Support sound null safety

### [~] 0/20 points: Package does not opt in to null safety.

<details>
<summary>
Package language version (indicated by the sdk constraint `<3.0.0`) is less than 2.12.
</summary>

Consider [migrating](https://dart.dev/null-safety/migration-guide).
</details>