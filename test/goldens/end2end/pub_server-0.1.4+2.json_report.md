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

### [~] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`dart2_constant`]|`^1.0.1`|1.0.2+dart2|1.0.2+dart2|
|[`http_parser`]|`^3.0.0`|3.1.4|**4.0.0**|
|[`logging`]|`>=0.9.3 <1.0.0`|0.11.4|**1.0.0**|
|[`mime`]|`>=0.9.3 <0.10.0`|0.9.7|**1.0.0**|
|[`pub_semver`]|`^1.1.0`|1.4.4|**2.0.0**|
|[`shelf`]|`>=0.5.6 <0.8.0`|0.7.9|**1.0.0**|
|[`yaml`]|`^2.1.2`|2.2.1|**3.0.0**|

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[`async`]|-|2.5.0|2.5.0|
|[`charcode`]|-|1.2.0|1.2.0|
|[`collection`]|-|1.15.0|1.15.0|
|[`source_span`]|-|1.8.1|1.8.1|
|[`stack_trace`]|-|1.10.0|1.10.0|
|[`stream_channel`]|-|2.1.0|2.1.0|
|[`string_scanner`]|-|1.1.0|1.1.0|
|[`term_glyph`]|-|1.2.0|1.2.0|
|[`typed_data`]|-|1.3.0|1.3.0|
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
[`source_span`]: https://pub.dev/packages/source_span
[`stack_trace`]: https://pub.dev/packages/stack_trace
[`stream_channel`]: https://pub.dev/packages/stream_channel
[`string_scanner`]: https://pub.dev/packages/string_scanner
[`term_glyph`]: https://pub.dev/packages/term_glyph
[`typed_data`]: https://pub.dev/packages/typed_data

Found 6 issues. Showing the first 2:

<details>
<summary>
The constraint `^3.0.0` on http_parser does not support the stable version `4.0.0`, that was published 10 days ago. 

 When http_parser is 30 days old, this package will no longer be awarded points in this category.
</summary>

Try running `dart pub upgrade --major-versions http_parser` to update the constraint.
</details>
<details>
<summary>
The constraint `>=0.9.3 <1.0.0` on logging does not support the stable version `1.0.0`, that was published 10 days ago. 

 When logging is 30 days old, this package will no longer be awarded points in this category.
</summary>

Try running `dart pub upgrade --major-versions logging` to update the constraint.
</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

* Found no Flutter in your PATH. Could not determine the current Flutter version.

## 0/0 Support sound null-safety

### [~] 0/0 points: Package does not opt in to null-safety.

Packages with full null-safety support will be awarded additional points in a planned future revision of the pub.dev points model.

<details>
<summary>
Package language version (indicated by the sdk constraint `>=2.0.0-dev <3.0.0`) is less than 2.12.
</summary>

Consider [migrating](https://dart.dev/null-safety/migration-guide).
</details>