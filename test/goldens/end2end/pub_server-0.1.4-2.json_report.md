## 20/20 Follow Dart file conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Provide documentation

### [*] 10/10 points: Package has an example

* Found example at: `example/example.dart`

## 20/20 Support multiple platforms

### [*] 20/20 points: Supports 2 of 2 possible platforms (**native**, **js**)


## 20/30 Pass static analysis

### [~] 20/30 points: code has no errors, warnings, lints, or formatting issues

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

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/repository.dart`
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

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/repository.dart`
</details>

## 10/20 Support up-to-date dependencies

### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`dart2_constant`]|`^1.0.1`|1.0.2+dart2|1.0.2+dart2|
|[`http_parser`]|`^3.0.0`|3.1.4|3.1.4|
|[`logging`]|`>=0.9.3 <1.0.0`|0.11.4|0.11.4|
|[`mime`]|`>=0.9.3 <0.10.0`|0.9.7|0.9.7|
|[`pub_semver`]|`^1.1.0`|1.4.4|1.4.4|
|[`shelf`]|`>=0.5.6 <0.8.0`|0.7.7|0.7.7|
|[`yaml`]|`^2.1.2`|2.2.1|2.2.1|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`async`]|-|2.4.2|2.4.2|
|[`charcode`]|-|1.1.3|1.1.3|
|[`collection`]|-|1.14.13|1.14.13|
|[`meta`]|-|1.2.2|1.2.2|
|[`source_span`]|-|1.7.0|1.7.0|
|[`stack_trace`]|-|1.9.5|1.9.5|
|[`stream_channel`]|-|2.0.0|2.0.0|
|[`string_scanner`]|-|1.0.5|1.0.5|
|[`term_glyph`]|-|1.1.0|1.1.0|
|[`typed_data`]|-|1.2.0|1.2.0|
</details>

To reproduce run `pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`dart2_constant`]: https://pub.dev/packages/dart2_constant
[`http_parser`]: https://pub.dev/packages/http_parser
[`logging`]: https://pub.dev/packages/logging
[`mime`]: https://pub.dev/packages/mime
[`pub_semver`]: https://pub.dev/packages/pub_semver
[`shelf`]: https://pub.dev/packages/shelf
[`yaml`]: https://pub.dev/packages/yaml
[`async`]: https://pub.dev/packages/async
[`charcode`]: https://pub.dev/packages/charcode
[`collection`]: https://pub.dev/packages/collection
[`meta`]: https://pub.dev/packages/meta
[`source_span`]: https://pub.dev/packages/source_span
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`stream_channel`]: https://pub.dev/packages/stream_channel
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data


### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.