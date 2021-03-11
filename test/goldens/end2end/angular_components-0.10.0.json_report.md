## 5/20 Follow Dart file conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

* Homepage URL isn't helpful.
* Documentation URL isn't helpful.

### [x] 0/5 points: Provide a valid `README.md`

<details>
<summary>
Links in `README.md` should be secure. 1 link is insecure.
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

Found 9871 issues. Showing the first 2:

<details>
<summary>
ERROR: Const variables must be initialized with a constant value.
</summary>

`lib/angular_components.dart:229:3`

```
    ╷
229 │   ClickableTooltipTargetDirective,
    │   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/angular_components.dart`
</details>
<details>
<summary>
ERROR: The values in a const list literal must be constants.
</summary>

`lib/angular_components.dart:229:3`

```
    ╷
229 │   ClickableTooltipTargetDirective,
    │   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/angular_components.dart`
</details>

## 0/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Could not run pub outdated: `pub get` failed: 

 ```
The current Dart SDK version is {{sdk-version}}.

Because observable >=0.1.1 <=0.22.1+3 requires SDK version <2.0.0 or >=2.0.0-dev.23.0 <2.0.0 and observable >=0.22.1+4 depends on dart_internal ^0.1.1, observable >=0.1.1 requires dart_internal ^0.1.1.
So, because dart_internal ^0.1.1 requires SDK version >=2.0.0-dev.12.0 <2.12.0 and angular_components depends on observable ^0.22.1+3, version solving failed.
```

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.

## 0/20 Support sound null-safety

### [x] 0/20 points: Unable to detect null safety

<details>
<summary>
Package resolution failed. Could not determine null-safety.
</summary>

Run `pub get` for more information.
</details>