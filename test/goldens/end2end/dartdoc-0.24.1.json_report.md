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

## 10/20 Support multiple platforms

### [~] 10/20 points: Supports 1 of 2 possible platforms (**native**, js)

Consider supporting multiple platforms:

<details>
<summary>
Package not compatible with runtime js
</summary>

Because:
* `package:dartdoc/dartdoc.dart` that imports:
* `package:dartdoc/src/element_type.dart` that imports:
* `package:dartdoc/src/model.dart` that imports:
* `package:package_config/discovery.dart` that imports:
* `package:package_config/src/packages_io_impl.dart` that imports:
* `package:package_config/src/util_io.dart` that imports:
* `dart:io`
</details>

## 20/30 Pass static analysis

### [~] 20/30 points: code has no errors, warnings, lints, or formatting issues

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

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer bin/dartdoc.dart`
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

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer bin/dartdoc.dart`
</details>

## 0/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`analyzer`]|`^0.33.0`|0.33.6+1|**0.39.16**|
|[`args`]|`>=1.4.1 <2.0.0`|1.6.0|1.6.0|
|[`collection`]|`^1.2.0`|1.14.13|1.14.13|
|[`crypto`]|`^2.0.6`|2.1.5|2.1.5|
|[`html`]|`>=0.12.1 <0.14.0`|0.13.4+2|**0.14.0+3**|
|[`http_parser`]|`>=3.0.3 <4.0.0`|3.1.4|3.1.4|
|[`logging`]|`^0.11.3+1`|0.11.4|0.11.4|
|[`markdown`]|`^2.0.0`|2.1.7|2.1.7|
|[`package_config`]|`>=0.1.5 <2.0.0`|1.9.3|1.9.3|
|[`path`]|`^1.3.0`|1.7.0|1.7.0|
|[`process`]|`^3.0.5`|3.0.13|3.0.13|
|[`pub_semver`]|`^1.3.7`|1.4.4|1.4.4|
|[`quiver`]|`^2.0.0`|2.1.3|2.1.3|
|[`resource`]|`^2.1.2`|2.1.7|2.1.7|
|[`stack_trace`]|`^1.4.2`|1.9.5|1.9.5|
|[`yaml`]|`^2.1.0`|2.2.1|2.2.1|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`async`]|-|2.4.2|2.4.2|
|[`charcode`]|-|1.1.3|1.1.3|
|[`convert`]|-|2.1.1|2.1.1|
|[`csslib`]|-|0.15.0|0.16.2|
|[`file`]|-|5.2.1|5.2.1|
|[`front_end`]|-|0.1.6+9|0.1.29|
|[`intl`]|-|0.16.1|0.16.1|
|[`js`]|-|0.6.2|0.6.2|
|[`kernel`]|-|0.3.6+9|0.3.29|
|[`matcher`]|-|0.12.9|0.12.9|
|[`node_interop`]|-|1.1.1|1.1.1|
|[`node_io`]|-|1.1.1|1.1.1|
|[`pedantic`]|-|1.9.2|1.9.2|
|[`platform`]|-|2.2.1|2.2.1|
|[`plugin`]|-|0.2.0+3|0.2.0+3|
|[`source_span`]|-|1.7.0|1.7.0|
|[`string_scanner`]|-|1.0.5|1.0.5|
|[`term_glyph`]|-|1.1.0|1.1.0|
|[`typed_data`]|-|1.2.0|1.2.0|
|[`utf`]|-|0.9.0+5|0.9.0+5|
|[`watcher`]|-|0.9.7+15|0.9.7+15|
</details>

To reproduce run `pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`analyzer`]: https://pub.dev/packages/analyzer
[`args`]: https://pub.dev/packages/args
[`collection`]: https://pub.dev/packages/collection
[`crypto`]: https://pub.dev/packages/crypto
[`html`]: https://pub.dev/packages/html
[`http_parser`]: https://pub.dev/packages/http_parser
[`logging`]: https://pub.dev/packages/logging
[`markdown`]: https://pub.dev/packages/markdown
[`package_config`]: https://pub.dev/packages/package_config
[`path`]: https://pub.dev/packages/path
[`process`]: https://pub.dev/packages/process
[`pub_semver`]: https://pub.dev/packages/pub_semver
[`quiver`]: https://pub.dev/packages/quiver
[`resource`]: https://pub.dev/packages/resource
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`yaml`]: https://pub.dev/packages/yaml
[`async`]: https://pub.dev/packages/async
[`charcode`]: https://pub.dev/packages/charcode
[`convert`]: https://pub.dev/packages/convert
[`csslib`]: https://pub.dev/packages/csslib
[`file`]: https://pub.dev/packages/file
[`front_end`]: https://pub.dev/packages/front_end
[`intl`]: https://pub.dev/packages/intl
[`js`]: https://pub.dev/packages/js
[`kernel`]: https://pub.dev/packages/kernel
[`matcher`]: https://pub.dev/packages/matcher
[`node_interop`]: https://pub.dev/packages/node_interop
[`node_io`]: https://pub.dev/packages/node_io
[`pedantic`]: https://pub.dev/packages/pedantic
[`platform`]: https://pub.dev/packages/platform
[`plugin`]: https://pub.dev/packages/plugin
[`source_span`]: https://pub.dev/packages/source_span
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data
[`utf`]: https://pub.dev/packages/utf
[`watcher`]: https://pub.dev/packages/watcher

<details>
<summary>
The constraint `^0.33.0` on analyzer does not support the latest published version `0.39.16`
</summary>

`pubspec.yaml:11:13`

```
   ╷
11 │   analyzer: ^0.33.0
   │             ^^^^^^^
   ╵
```

</details>
<details>
<summary>
The constraint `>=0.12.1 <0.14.0` on html does not support the latest published version `0.14.0+3`
</summary>

`pubspec.yaml:15:9`

```
   ╷
15 │   html: '>=0.12.1 <0.14.0'
   │         ^^^^^^^^^^^^^^^^^^
   ╵
```

</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.