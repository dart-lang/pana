## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/example.dart`

## 10/20 Support multiple platforms

### [~] 10/20 points: Supports 1 of 2 possible platforms (native, **js**)

Consider supporting multiple platforms:

<details>
<summary>
Package not compatible with runtime native
</summary>

Because:
* `package:dnd/dnd.dart` that imports:
* `dart:js`
</details>

## 20/30 Pass static analysis

### [~] 20/30 points: code has no errors, warnings, lints, or formatting issues

Found 24 issues. Showing the first 2:

<details>
<summary>
INFO: Prefer using `??=` over testing for null.
</summary>

`lib/src/draggable.dart:82:5`

```
   ╷
82 │ ┌     if (_onDragStart == null) {
83 │ │       _onDragStart = StreamController<DraggableEvent>.broadcast(
84 │ │           sync: true, onCancel: () => _onDragStart = null);
85 │ └     }
   ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/src/draggable.dart`
</details>
<details>
<summary>
INFO: Prefer using `??=` over testing for null.
</summary>

`lib/src/draggable.dart:91:5`

```
   ╷
91 │ ┌     if (_onDrag == null) {
92 │ │       _onDrag = StreamController<DraggableEvent>.broadcast(
93 │ │           sync: true, onCancel: () => _onDrag = null);
94 │ └     }
   ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/src/draggable.dart`
</details>

## 10/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

No dependencies.

To reproduce run `pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.


### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.

## 20/20 Support sound null safety

### [*] 20/20 points: Package and dependencies are fully migrated to null safety!
