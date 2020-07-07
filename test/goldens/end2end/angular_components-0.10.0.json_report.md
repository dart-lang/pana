## 5/20 Packaging conventions

### [x] 0/10 points: Provide a valid pubspec.yaml

* Homepage URL isn't helpful.
* Documentation URL isn't helpful.

### [x] 0/5 points: Provide a valid README.md

<details>
<summary>
Links in README.md should be secure. 1 link is insecure.
</summary>

`README.md:51:22`

```
   ╷
51 │ component's provided <a href="http://sass-lang.com/guide#topic-6">Sass mixins</a>.</p>
   │                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   ╵
```

Use `https` URLs instead.
</details>

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

### [~] 10/20 points: Supports 1 of 2 possible platforms (native, **js**)

<details>
<summary>
Package not compatible with runtime native-aot
</summary>

Because:
* `package:angular_components/angular_components.dart` that imports:
* `package:angular_components/theme/module.dart` that imports:
* `package:angular/angular.dart` that imports:
* `package:angular/src/platform/browser/tools/tools.dart` that imports:
* `package:angular/src/platform/browser/tools/common_tools.dart` that imports:
* `package:angular/src/core/linker/component_factory.dart` that imports:
* `package:angular/src/core/linker/view_ref.dart` that imports:
* `dart:html`
</details>
<details>
<summary>
Package not compatible with runtime native
</summary>

Because:
* `package:angular_components/angular_components.dart` that imports:
* `package:angular_components/theme/module.dart` that imports:
* `package:angular/angular.dart` that imports:
* `package:angular/src/platform/browser/tools/tools.dart` that imports:
* `package:angular/src/platform/browser/tools/common_tools.dart` that imports:
* `package:angular/src/core/linker/component_factory.dart` that imports:
* `package:angular/src/core/linker/view_ref.dart` that imports:
* `dart:html`
</details>

## 0/20 Code follows recommended code style

### [x] 0/20 points: code has no errors, warnings, lints, or formatting issues

Found 900 issues. Showing the first 2:

<details>
<summary>
ERROR: The method 'dispose' isn't defined for the type 'Object'.
</summary>

`lib/model/collection/list_tracker.dart:123:9`

```
    ╷
123 │       d.dispose();
    │         ^^^^^^^
    ╵
```

To reproduce run `dart analyze lib/model/collection/list_tracker.dart`
</details>
<details>
<summary>
WARNING: Parameters can't override default values, this method overrides 'SelectionObservable.notifySelectionChange' where 'added' has a different value.
</summary>

`lib/src/model/selection/noop_selection_model_impl.dart:20:31`

```
   ╷
20 │   void notifySelectionChange({added, removed}) {}
   │                               ^^^^^
   ╵
```

To reproduce run `dart analyze lib/src/model/selection/noop_selection_model_impl.dart`
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