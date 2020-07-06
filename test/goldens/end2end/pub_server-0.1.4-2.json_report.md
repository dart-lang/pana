## 20/20 Packaging conventions

### [*] 10/10 points: Provide a valid pubspec.yaml


### [*] 5/5 points: Provide a valid README.md


### [*] 5/5 points: Provide a valid CHANGELOG.md


## 10/10 Package has documentation

### [*] 10/10 points: Package has an example

* Found example at: example/example.dart

## 20/20 Package is multi-platform

### [*] 20/20 points: Supports 2 of 2 possible platforms (native, js)


## 10/20 Code follows recommended code style

### [~] 10/20 points: code has no errors, warnings, lints, or formatting issues

Found 44 issues. Showing the first 2:

<details>
<summary>
INFO: Unnecessary new keyword.
</summary>

`lib/repository.dart:27:15`

```
   ╷
27 │     _cached = new Version.parse(versionString);
   │               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   ╵
```

To reproduce run `dart analyze lib/repository.dart`
</details>
<details>
<summary>
INFO: Unnecessary new keyword.
</summary>

`lib/repository.dart:109:7`

```
    ╷
109 │       new GenericProcessingException('ValidationError: $message');
    │       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ╵
```

To reproduce run `dart analyze lib/repository.dart`
</details>

## 10/30 Package is a good, trustworthy dependency

### [*] 10/10 points: All of the package dependencies are supported in the latest version


### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.

### [x] 0/10 points: Package is published using a verified publisher

<details>
<summary>
Package is not published under a verified publisher.
</summary>

See https://dart.dev/tools/pub/verified-publishers for more information.
</details>