## 20/20 Packaging conventions

### [*] 10/10 points: Provide a valid `pubspec.yaml`


### [*] 5/5 points: Provide a valid `README.md`


### [*] 5/5 points: Provide a valid `CHANGELOG.md`


## 10/10 Package has documentation

### [*] 10/10 points: Package has an example

* Found example at: example/example.dart

## 20/20 Package is multi-platform

### [*] 20/20 points: Supports 2 of 2 possible platforms (**native**, **js**)


## 10/20 Code follows recommended code style

### [~] 10/20 points: code has no errors, warnings, lints, or formatting issues

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

To reproduce run `dart analyze lib/repository.dart`
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

To reproduce run `dart analyze lib/repository.dart`
</details>

## 0/30 Package is a good, trustworthy dependency

### [x] 0/10 points: All of the package dependencies are supported in the latest version

<details>
<summary>
Dependencies
</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[dart2_constant]|^1.0.1|1.0.2+dart2|1.0.2+dart2|
|[http_parser]|^3.0.0|3.1.4|3.1.4|
|[logging]|>=0.9.3 <1.0.0|0.11.4|0.11.4|
|[mime]|>=0.9.3 <0.10.0|0.9.6+3|0.9.6+3|
|[pub_semver]|^1.1.0|1.4.4|1.4.4|
|[shelf]|>=0.5.6 <0.8.0|0.7.7|0.7.7|
|[yaml]|^2.1.2|2.2.1|2.2.1|
|**Transitive dependencies**|
|[async]|-|2.4.2|2.4.2|
|[charcode]|-|1.1.3|1.1.3|
|[collection]|-|1.14.13|1.14.13|
|[meta]|-|1.2.1|1.2.1|
|[source_span]|-|1.7.0|1.7.0|
|[stack_trace]|-|1.9.5|1.9.5|
|[stream_channel]|-|2.0.0|2.0.0|
|[string_scanner]|-|1.0.5|1.0.5|
|[term_glyph]|-|1.1.0|1.1.0|
|[typed_data]|-|1.2.0|1.2.0|
|[_fe_analyzer_shared]|-|5.0.0|5.0.0|
|[analyzer]|-|0.39.12|0.39.12|
|[boolean_selector]|-|2.0.0|2.0.0|
|[convert]|-|2.1.1|2.1.1|
|[coverage]|-|0.14.0|0.14.0|
|[crypto]|-|2.1.5|2.1.5|
|[csslib]|-|0.16.1|0.16.1|
|[glob]|-|1.2.0|1.2.0|
|[html]|-|0.14.0+3|0.14.0+3|
|[http_multi_server]|-|2.2.0|2.2.0|
|[io]|-|0.3.4|0.3.4|
|[js]|-|0.6.2|0.6.2|
|[matcher]|-|0.12.8|0.12.8|
|[multi_server_socket]|-|1.0.2|1.0.2|
|[node_interop]|-|1.1.1|1.1.1|
|[node_io]|-|1.1.1|1.1.1|
|[node_preamble]|-|1.4.12|1.4.12|
|[package_config]|-|1.9.3|1.9.3|
|[package_resolver]|-|1.0.10|1.0.10|
|[pedantic]|-|1.9.1|1.9.1|
|[pool]|-|1.4.0|1.4.0|
|[shelf_packages_handler]|-|2.0.0|2.0.0|
|[shelf_static]|-|0.2.8|0.2.8|
|[shelf_web_socket]|-|0.2.3|0.2.3|
|[source_map_stack_trace]|-|2.0.0|2.0.0|
|[source_maps]|-|0.10.9|0.10.9|
|[test_api]|-|0.2.17|0.2.17|
|[test_core]|-|0.3.10|0.3.10|
|[vm_service]|-|4.1.0|4.1.0|
|[watcher]|-|0.9.7+15|0.9.7+15|
|[web_socket_channel]|-|1.1.0|1.1.0|

To reproduce run `pub outdated --no-dev-dependencies --up-to-date`.

[dart2_constant]: https://pub.dev/packages/dart2_constant
[http_parser]: https://pub.dev/packages/http_parser
[logging]: https://pub.dev/packages/logging
[mime]: https://pub.dev/packages/mime
[pub_semver]: https://pub.dev/packages/pub_semver
[shelf]: https://pub.dev/packages/shelf
[yaml]: https://pub.dev/packages/yaml
[async]: https://pub.dev/packages/async
[charcode]: https://pub.dev/packages/charcode
[collection]: https://pub.dev/packages/collection
[meta]: https://pub.dev/packages/meta
[source_span]: https://pub.dev/packages/source_span
[stack_trace]: https://pub.dev/packages/stack_trace
[stream_channel]: https://pub.dev/packages/stream_channel
[string_scanner]: https://pub.dev/packages/string_scanner
[term_glyph]: https://pub.dev/packages/term_glyph
[typed_data]: https://pub.dev/packages/typed_data
[_fe_analyzer_shared]: https://pub.dev/packages/_fe_analyzer_shared
[analyzer]: https://pub.dev/packages/analyzer
[boolean_selector]: https://pub.dev/packages/boolean_selector
[convert]: https://pub.dev/packages/convert
[coverage]: https://pub.dev/packages/coverage
[crypto]: https://pub.dev/packages/crypto
[csslib]: https://pub.dev/packages/csslib
[glob]: https://pub.dev/packages/glob
[html]: https://pub.dev/packages/html
[http_multi_server]: https://pub.dev/packages/http_multi_server
[io]: https://pub.dev/packages/io
[js]: https://pub.dev/packages/js
[matcher]: https://pub.dev/packages/matcher
[multi_server_socket]: https://pub.dev/packages/multi_server_socket
[node_interop]: https://pub.dev/packages/node_interop
[node_io]: https://pub.dev/packages/node_io
[node_preamble]: https://pub.dev/packages/node_preamble
[package_config]: https://pub.dev/packages/package_config
[package_resolver]: https://pub.dev/packages/package_resolver
[pedantic]: https://pub.dev/packages/pedantic
[pool]: https://pub.dev/packages/pool
[shelf_packages_handler]: https://pub.dev/packages/shelf_packages_handler
[shelf_static]: https://pub.dev/packages/shelf_static
[shelf_web_socket]: https://pub.dev/packages/shelf_web_socket
[source_map_stack_trace]: https://pub.dev/packages/source_map_stack_trace
[source_maps]: https://pub.dev/packages/source_maps
[test_api]: https://pub.dev/packages/test_api
[test_core]: https://pub.dev/packages/test_core
[vm_service]: https://pub.dev/packages/vm_service
[watcher]: https://pub.dev/packages/watcher
[web_socket_channel]: https://pub.dev/packages/web_socket_channel

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