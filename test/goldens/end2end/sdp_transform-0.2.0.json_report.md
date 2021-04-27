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

Found 49 issues. Showing the first 2:

<details>
<summary>
INFO: The type of the function literal can't be inferred because the literal has a block as its body.
</summary>

`lib/src/grammar.dart:90:17`

```
   ╷
90 │         'format': (o) {
   │ ┌─────────────────^
91 │ │         return (o['encoding'] != null)
92 │ │             ? 'rtpmap:%d %s/%s/%s'
93 │ │             : (o['rate'] != null) ? 'rtpmap:%d %s/%s' : 'rtpmap:%d %s';
94 │ └       }
   ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/src/grammar.dart`
</details>
<details>
<summary>
INFO: The type of the function literal can't be inferred because the literal has a block as its body.
</summary>

`lib/src/grammar.dart:115:17`

```
    ╷
115 │         'format': (o) {
    │ ┌─────────────────^
116 │ │         return (o['address'] != null) ? 'rtcp:%d %s IP%d %s' : 'rtcp:%d';
117 │ └       }
    ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/src/grammar.dart`
</details>

## 10/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Could not run `dart pub outdated`: `dart pub get` failed: 

 ```
pubspec.yaml has no lower-bound SDK constraint.
You should edit pubspec.yaml to contain an SDK constraint:

environment:
  sdk: '>={{version}} <{{version}}'

See https://dart.dev/go/sdk-constraint
```

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs


## 0/20 Support sound null safety

### [~] 0/20 points: Package does not opt in to null safety.

<details>
<summary>
Package language version (indicated by the sdk constraint `<{{version}}`) is less than 2.12.
</summary>

Consider [migrating](https://dart.dev/null-safety/migration-guide).
</details>