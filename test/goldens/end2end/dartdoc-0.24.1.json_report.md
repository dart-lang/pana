## 5/20 Packaging conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
The package description is too short.
</summary>

Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 characters to describe the package, what it does, and its target use case.
</details>

### [x] 0/5 points: Provide a valid `README.md`

<details>
<summary>
Links in `README.md` should be secure. 1 link is insecure.
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

### [*] 5/5 points: Provide a valid `CHANGELOG.md`


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
Package not compatible with runtime native-aot
</summary>

Because:
* `package:dartdoc/dartdoc.dart` that imports:
* `package:dartdoc/src/html/html_generator.dart` that imports:
* `package:dartdoc/src/html/templates.dart` that imports:
* `package:dartdoc/src/third_party/pkg/mustache4dart/lib/mustache4dart.dart` that imports:
* `package:dartdoc/src/third_party/pkg/mustache4dart/lib/mustache_context.dart` that imports:
* `package:dartdoc/src/third_party/pkg/mustache4dart/lib/src/mirrors.dart` that imports:
* `dart:mirrors`
</details>
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

<details>
<summary>
Dependencies
</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`analyzer`]|^0.33.0|0.33.6+1|0.39.12|
|[`args`]|>=1.4.1 <2.0.0|1.6.0|1.6.0|
|[`collection`]|^1.2.0|1.14.13|1.14.13|
|[`crypto`]|^2.0.6|2.1.5|2.1.5|
|[`html`]|>=0.12.1 <0.14.0|0.13.4+2|0.14.0+3|
|[`http_parser`]|>=3.0.3 <4.0.0|3.1.4|3.1.4|
|[`logging`]|^0.11.3+1|0.11.4|0.11.4|
|[`markdown`]|^2.0.0|2.1.5|2.1.5|
|[`package_config`]|>=0.1.5 <2.0.0|1.9.3|1.9.3|
|[`path`]|^1.3.0|1.7.0|1.7.0|
|[`process`]|^3.0.5|3.0.13|3.0.13|
|[`pub_semver`]|^1.3.7|1.4.4|1.4.4|
|[`quiver`]|^2.0.0|2.1.3|2.1.3|
|[`resource`]|^2.1.2|2.1.7|2.1.7|
|[`stack_trace`]|^1.4.2|1.9.5|1.9.5|
|[`yaml`]|^2.1.0|2.2.1|2.2.1|
|**Transitive dependencies**|
|[`async`]|-|2.4.2|2.4.2|
|[`charcode`]|-|1.1.3|1.1.3|
|[`convert`]|-|2.1.1|2.1.1|
|[`csslib`]|-|0.15.0|0.16.1|
|[`file`]|-|5.2.1|5.2.1|
|[`front_end`]|-|0.1.6+9|0.1.29|
|[`intl`]|-|0.16.1|0.16.1|
|[`js`]|-|0.6.2|0.6.2|
|[`kernel`]|-|0.3.6+9|0.3.29|
|[`matcher`]|-|0.12.8|0.12.8|
|[`node_interop`]|-|1.1.1|1.1.1|
|[`node_io`]|-|1.1.1|1.1.1|
|[`pedantic`]|-|1.9.1|1.9.1|
|[`platform`]|-|2.2.1|2.2.1|
|[`plugin`]|-|0.2.0+3|0.2.0+3|
|[`source_span`]|-|1.7.0|1.7.0|
|[`string_scanner`]|-|1.0.5|1.0.5|
|[`term_glyph`]|-|1.1.0|1.1.0|
|[`typed_data`]|-|1.2.0|1.2.0|
|[`utf`]|-|0.9.0+5|0.9.0+5|
|[`watcher`]|-|0.9.7+15|0.9.7+15|

To reproduce run `pub outdated --no-dev-dependencies --up-to-date`.

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

</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.

### [x] 0/10 points: Package is published using a verified publisher

<details>
<summary>
Package is not published under a verified publisher.
</summary>

See https://dart.dev/tools/pub/verified-publishers for more information.
</details>