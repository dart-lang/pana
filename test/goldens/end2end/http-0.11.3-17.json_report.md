## 10/20 Packaging conventions

### [x] 0/10 points: Provide a valid pubspec.yaml
<details>
<summary>
`pubspec.yaml` doesn't have a `repository` entry.
</summary>
</details>
<details>
<summary>
`pubspec.yaml` doesn't have a `documentation` entry.
</summary>
</details>
<details>
<summary>
`pubspec.yaml` doesn't have a `issue_tracker` entry.
</summary>
</details>
<details>
<summary>
The package description is too short.
</summary>
Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 characters to describe the package, what it does, and its target use case.
</details>

### [*] 5/5 points: Provide a valid README.md


### [*] 5/5 points: Provide a valid CHANGELOG.md


## 0/10 Package has documentation

*10 points*: The package has an example.

No example found. See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.

## 20/20 Package is multi-platform

### [*] 20/20 points: Supports 2 of 2 possible platforms (native, js)


## 10/20 Code follows recommended code style

### [~] 10/20 points: code has no errors, warnings, lints, or formatting issues
Found 202 issues. Showing the first 2:

<details>
<summary>
INFO: Use collection literals when possible.
</summary>
`lib/browser_client.dart:30:17`

```
   ╷
30 │   final _xhrs = new Set<HttpRequest>();
   │                 ^^^^^^^^^^^^^^^^^^^^^^
   ╵
```

To reproduce run `dart analyze lib/browser_client.dart`
</details>
<details>
<summary>
INFO: Unnecessary new keyword.
</summary>
`lib/browser_client.dart:30:17`

```
   ╷
30 │   final _xhrs = new Set<HttpRequest>();
   │                 ^^^^^^^^^^^^^^^^^^^^^^
   ╵
```

To reproduce run `dart analyze lib/browser_client.dart`
</details>

## 20/30 Package is a good, trustworthy dependency

### [*] 10/10 points: All of the package dependencies are supported in the latest version


### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs
<details>
<summary>
Found no Flutter in your PATH. Could not determine the current Flutter version.
</summary>
</details>

### [*] 10/10 points: Package is published using a verified publisher
