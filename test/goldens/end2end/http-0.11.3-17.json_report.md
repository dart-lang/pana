## 10/20 Packaging conventions

### [x] 0/10 points: Provide a valid pubspec.yaml

<details>
<summary>
The package description is too short.
</summary>
Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 characters to describe the package, what it does, and its target use case.
</details>

### [*] 5/5 points: Provide a valid README.md


### [*] 5/5 points: Provide a valid CHANGELOG.md


## 0/10 Package has documentation

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>
See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>

## 10/20 Package is multi-platform

### [~] 10/20 points: Supports 1 of 2 possible platforms (**native**, js)

<details>
<summary>
Package not compatible with runtime web
</summary>
Because of the import of dart:io via the import chain `package:http/http.dart` → `package:http/src/streamed_response.dart` → `package:http/src/base_request.dart` → `package:http/src/client.dart` → `package:http/src/io_client.dart` → `dart:io`
</details>

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

* Found no Flutter in your PATH. Could not determine the current Flutter version.

### [*] 10/10 points: Package is published using a verified publisher
