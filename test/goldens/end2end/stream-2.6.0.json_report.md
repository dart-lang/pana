## 5/20 Follow Dart file conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
Homepage URL is insecure.
</summary>

Update the `homepage` field and use a secure (`https`) URL.
</details>
<details>
<summary>
Documentation URL is insecure.
</summary>

Update the `documentation` field and use a secure (`https`) URL.
</details>

### [x] 0/5 points: Provide a valid `README.md`

<details>
<summary>
Links in `README.md` should be secure. 9 links are insecure.
</summary>

`README.md:2:4`

```
  ╷
2 │ <p><a href="http://rikulo.org/projects/stream">Stream</a> is a Dart web server supporting request routing, filtering, template engine, WebSocket, MVC design pattern and file-based static resources.</p>
  │    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
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

## 10/20 Support multiple platforms

### [~] 10/20 points: Supports 1 of 2 possible platforms (**native**, js)

Consider supporting multiple platforms:

<details>
<summary>
Package not compatible with runtime js
</summary>

Because:
* `package:stream/stream.dart` that imports:
* `package:stream/plugin.dart` that imports:
* `package:rikulo_commons/io.dart` that imports:
* `dart:io`
</details>

## 20/30 Pass static analysis

### [~] 20/30 points: code has no errors, warnings, lints, or formatting issues

Found 1191 issues. Showing the first 2:

<details>
<summary>
INFO: Only use double quotes for strings containing single quotes.
</summary>

`bin/rspc.dart:10:8`

```
   ╷
10 │ import "package:stream/rspc.dart" as rspc;
   │        ^^^^^^^^^^^^^^^^^^^^^^^^^^
   ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer bin/rspc.dart`
</details>
<details>
<summary>
INFO: Only use double quotes for strings containing single quotes.
</summary>

`lib/plugin.dart:6:8`

```
  ╷
6 │ import "dart:async";
  │        ^^^^^^^^^^^^
  ╵
```

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/plugin.dart`
</details>

## 0/20 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`args`]|`>=0.13.0 <2.0.0`|1.6.0|**2.0.0**|
|[`charcode`]|`>=1.1.0 <2.0.0`|1.2.0|1.2.0|
|[`http`]|`>=0.11.0 <2.0.0`|0.13.1|0.13.1|
|[`logging`]|`>=0.11.0 <2.0.0`|1.0.0|1.0.0|
|[`path`]|`>=1.3.0 <2.0.0`|1.8.0|1.8.0|
|[`rikulo_commons`]|`>=4.1.0 <5.0.0`|4.3.0|4.3.0|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`collection`]|-|1.15.0|1.15.0|
|[`http_parser`]|-|4.0.0|4.0.0|
|[`meta`]|-|1.3.0|1.3.0|
|[`mime`]|-|1.0.0|1.0.0|
|[`pedantic`]|-|1.11.0|1.11.0|
|[`source_span`]|-|1.8.1|1.8.1|
|[`string_scanner`]|-|1.1.0|1.1.0|
|[`term_glyph`]|-|1.2.0|1.2.0|
|[`typed_data`]|-|1.3.0|1.3.0|
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`args`]: https://pub.dev/packages/args
[`charcode`]: https://pub.dev/packages/charcode
[`http`]: https://pub.dev/packages/http
[`logging`]: https://pub.dev/packages/logging
[`path`]: https://pub.dev/packages/path
[`rikulo_commons`]: https://pub.dev/packages/rikulo_commons
[`collection`]: https://pub.dev/packages/collection
[`http_parser`]: https://pub.dev/packages/http_parser
[`meta`]: https://pub.dev/packages/meta
[`mime`]: https://pub.dev/packages/mime
[`pedantic`]: https://pub.dev/packages/pedantic
[`source_span`]: https://pub.dev/packages/source_span
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data

<details>
<summary>
The constraint `>=0.13.0 <2.0.0` on args does not support the stable version `2.0.0`.
</summary>

Try running `dart pub upgrade --major-versions args` to update the constraint.
</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.

## 0/20 Support sound null safety

### [~] 0/20 points: Package does not opt in to null safety.

<details>
<summary>
Package language version (indicated by the sdk constraint `>=2.8.0 <3.0.0`) is less than 2.12.
</summary>

Consider [migrating](https://dart.dev/null-safety/migration-guide).
</details>