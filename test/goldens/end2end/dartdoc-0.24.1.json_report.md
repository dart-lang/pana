## 5/20 Packaging conventions

### [x] 0/10 points: Provide a valid pubspec.yaml

<details>
<summary>
The package description is too short.
</summary>
Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 characters to describe the package, what it does, and its target use case.
</details>

### [x] 0/5 points: Provide a valid README.md

<details>
<summary>
Links in README.md should be secure. 1 link is insecure.
</summary>
`README.md:319:55`

```
    ╷
319 │ <li>With <code>github.css</code> (c) Vasily Polovnyov <a href="mailto:vast@whiteants.net">vast@whiteants.net</a></li>
    │                                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
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

## 0/20 Package is multi-platform

### [x] 0/20 points: Supports 0 of 2 possible platforms (native, js)

<details>
<summary>
Package not compatible with runtime native-aot
</summary>
Because of the import of dart:mirrors via the import chain `package:dartdoc/dartdoc.dart` → `package:dartdoc/src/html/html_generator.dart` → `package:dartdoc/src/html/templates.dart` → `package:dartdoc/src/third_party/pkg/mustache4dart/lib/mustache4dart.dart` → `package:dartdoc/src/third_party/pkg/mustache4dart/lib/mustache_context.dart` → `package:dartdoc/src/third_party/pkg/mustache4dart/lib/src/mirrors.dart` → `dart:mirrors`
</details>
<details>
<summary>
Package not compatible with runtime js
</summary>
Because of the import of dart:io via the import chain `package:dartdoc/dartdoc.dart` → `package:dartdoc/src/element_type.dart` → `package:dartdoc/src/model.dart` → `package:package_config/discovery.dart` → `package:package_config/src/packages_io_impl.dart` → `package:package_config/src/util_io.dart` → `dart:io`
</details>

## 10/20 Code follows recommended code style

### [~] 10/20 points: code has no errors, warnings, lints, or formatting issues

Found 1887 issues. Showing the first 2:

<details>
<summary>
INFO: Unnecessary new keyword.
</summary>
`bin/dartdoc.dart:27:5`

```
   ╷
27 │ ┌     new DartdocOptionArgOnly<bool>('help', false,
28 │ │         abbr: 'h', help: 'Show command help.', negatable: false),
   │ └────────────────────────────────────────────────────────────────^
   ╵
```

To reproduce run `dart analyze bin/dartdoc.dart`
</details>
<details>
<summary>
INFO: Unnecessary new keyword.
</summary>
`bin/dartdoc.dart:29:5`

```
   ╷
29 │ ┌     new DartdocOptionArgOnly<bool>('version', false,
30 │ │         help: 'Display the version for $name.', negatable: false),
   │ └─────────────────────────────────────────────────────────────────^
   ╵
```

To reproduce run `dart analyze bin/dartdoc.dart`
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