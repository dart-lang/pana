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

## 0/30 Package is a good, trustworthy dependency

### [x] 0/10 points: All of the package dependencies are supported in the latest version

<details>
<summary>
Dependencies
</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[analyzer]|^0.33.0|0.33.6+1|0.39.12|
|[args]|>=1.4.1 <2.0.0|1.6.0|1.6.0|
|[collection]|^1.2.0|1.14.13|1.14.13|
|[crypto]|^2.0.6|2.1.5|2.1.5|
|[html]|>=0.12.1 <0.14.0|0.13.4+2|0.14.0+3|
|[http_parser]|>=3.0.3 <4.0.0|3.1.4|3.1.4|
|[logging]|^0.11.3+1|0.11.4|0.11.4|
|[markdown]|^2.0.0|2.1.5|2.1.5|
|[package_config]|>=0.1.5 <2.0.0|1.9.3|1.9.3|
|[path]|^1.3.0|1.7.0|1.7.0|
|[process]|^3.0.5|3.0.13|3.0.13|
|[pub_semver]|^1.3.7|1.4.4|1.4.4|
|[quiver]|^2.0.0|2.1.3|2.1.3|
|[resource]|^2.1.2|2.1.7|2.1.7|
|[stack_trace]|^1.4.2|1.9.5|1.9.5|
|[yaml]|^2.1.0|2.2.1|2.2.1|
|**Transitive dependencies**|
|[_fe_analyzer_shared]|-|5.0.0|5.0.0|
|[async]|-|2.4.2|2.4.2|
|[charcode]|-|1.1.3|1.1.3|
|[convert]|-|2.1.1|2.1.1|
|[csslib]|-|0.16.1|0.16.1|
|[file]|-|5.2.1|5.2.1|
|[front_end]|-|0.1.29|0.1.29|
|[intl]|-|0.16.1|0.16.1|
|[js]|-|0.6.2|0.6.2|
|[kernel]|-|0.3.29|0.3.29|
|[matcher]|-|0.12.8|0.12.8|
|[node_interop]|-|1.1.1|1.1.1|
|[node_io]|-|1.1.1|1.1.1|
|[pedantic]|-|1.9.1|1.9.1|
|[platform]|-|2.2.1|2.2.1|
|[plugin]|-|0.2.0+3|0.2.0+3|
|[source_span]|-|1.7.0|1.7.0|
|[string_scanner]|-|1.0.5|1.0.5|
|[term_glyph]|-|1.1.0|1.1.0|
|[typed_data]|-|1.2.0|1.2.0|
|[utf]|-|0.9.0+5|0.9.0+5|
|[watcher]|-|0.9.7+15|0.9.7+15|
|[boolean_selector]|-|2.0.0|2.0.0|
|[build_cli_annotations]|-|1.2.0|1.2.0|
|[build_config]|-|0.4.2|0.4.2|
|[build_resolvers]|-|1.3.10|1.3.10|
|[build_runner_core]|-|6.0.0|6.0.0|
|[built_collection]|-|4.3.2|4.3.2|
|[built_value]|-|7.1.0|7.1.0|
|[checked_yaml]|-|1.0.2|1.0.2|
|[cli_util]|-|0.2.0|0.2.0|
|[code_builder]|-|3.3.0|3.3.0|
|[dart_style]|-|1.3.6|1.3.6|
|[fixnum]|-|0.10.11|0.10.11|
|[graphs]|-|0.2.0|0.2.0|
|[http_multi_server]|-|2.2.0|2.2.0|
|[json_annotation]|-|3.0.1|3.0.1|
|[json_rpc_2]|-|2.2.1|2.2.1|
|[mime]|-|0.9.6+3|0.9.6+3|
|[multi_server_socket]|-|1.0.2|1.0.2|
|[node_preamble]|-|1.4.12|1.4.12|
|[package_resolver]|-|1.0.10|1.0.10|
|[pool]|-|1.4.0|1.4.0|
|[pubspec_parse]|-|0.1.5|0.1.5|
|[shelf]|-|0.7.7|0.7.7|
|[shelf_packages_handler]|-|2.0.0|2.0.0|
|[shelf_static]|-|0.2.8|0.2.8|
|[shelf_web_socket]|-|0.2.3|0.2.3|
|[source_map_stack_trace]|-|2.0.0|2.0.0|
|[source_maps]|-|0.10.9|0.10.9|
|[stream_channel]|-|2.0.0|2.0.0|
|[stream_transform]|-|1.2.0|1.2.0|
|[test_api]|-|0.2.17|0.2.17|
|[test_core]|-|0.3.10|0.3.10|
|[timing]|-|0.1.1+2|0.1.1+2|
|[vm_service_client]|-|0.2.6+3|0.2.6+3|
|[web_socket_channel]|-|1.1.0|1.1.0|

To reproduce run `pub outdated --no-dev-dependencies --up-to-date`.

[analyzer]: https://pub.dev/packages/analyzer
[args]: https://pub.dev/packages/args
[collection]: https://pub.dev/packages/collection
[crypto]: https://pub.dev/packages/crypto
[html]: https://pub.dev/packages/html
[http_parser]: https://pub.dev/packages/http_parser
[logging]: https://pub.dev/packages/logging
[markdown]: https://pub.dev/packages/markdown
[package_config]: https://pub.dev/packages/package_config
[path]: https://pub.dev/packages/path
[process]: https://pub.dev/packages/process
[pub_semver]: https://pub.dev/packages/pub_semver
[quiver]: https://pub.dev/packages/quiver
[resource]: https://pub.dev/packages/resource
[stack_trace]: https://pub.dev/packages/stack_trace
[yaml]: https://pub.dev/packages/yaml
[_fe_analyzer_shared]: https://pub.dev/packages/_fe_analyzer_shared
[async]: https://pub.dev/packages/async
[charcode]: https://pub.dev/packages/charcode
[convert]: https://pub.dev/packages/convert
[csslib]: https://pub.dev/packages/csslib
[file]: https://pub.dev/packages/file
[front_end]: https://pub.dev/packages/front_end
[intl]: https://pub.dev/packages/intl
[js]: https://pub.dev/packages/js
[kernel]: https://pub.dev/packages/kernel
[matcher]: https://pub.dev/packages/matcher
[node_interop]: https://pub.dev/packages/node_interop
[node_io]: https://pub.dev/packages/node_io
[pedantic]: https://pub.dev/packages/pedantic
[platform]: https://pub.dev/packages/platform
[plugin]: https://pub.dev/packages/plugin
[source_span]: https://pub.dev/packages/source_span
[string_scanner]: https://pub.dev/packages/string_scanner
[term_glyph]: https://pub.dev/packages/term_glyph
[typed_data]: https://pub.dev/packages/typed_data
[utf]: https://pub.dev/packages/utf
[watcher]: https://pub.dev/packages/watcher
[boolean_selector]: https://pub.dev/packages/boolean_selector
[build_cli_annotations]: https://pub.dev/packages/build_cli_annotations
[build_config]: https://pub.dev/packages/build_config
[build_resolvers]: https://pub.dev/packages/build_resolvers
[build_runner_core]: https://pub.dev/packages/build_runner_core
[built_collection]: https://pub.dev/packages/built_collection
[built_value]: https://pub.dev/packages/built_value
[checked_yaml]: https://pub.dev/packages/checked_yaml
[cli_util]: https://pub.dev/packages/cli_util
[code_builder]: https://pub.dev/packages/code_builder
[dart_style]: https://pub.dev/packages/dart_style
[fixnum]: https://pub.dev/packages/fixnum
[graphs]: https://pub.dev/packages/graphs
[http_multi_server]: https://pub.dev/packages/http_multi_server
[json_annotation]: https://pub.dev/packages/json_annotation
[json_rpc_2]: https://pub.dev/packages/json_rpc_2
[mime]: https://pub.dev/packages/mime
[multi_server_socket]: https://pub.dev/packages/multi_server_socket
[node_preamble]: https://pub.dev/packages/node_preamble
[package_resolver]: https://pub.dev/packages/package_resolver
[pool]: https://pub.dev/packages/pool
[pubspec_parse]: https://pub.dev/packages/pubspec_parse
[shelf]: https://pub.dev/packages/shelf
[shelf_packages_handler]: https://pub.dev/packages/shelf_packages_handler
[shelf_static]: https://pub.dev/packages/shelf_static
[shelf_web_socket]: https://pub.dev/packages/shelf_web_socket
[source_map_stack_trace]: https://pub.dev/packages/source_map_stack_trace
[source_maps]: https://pub.dev/packages/source_maps
[stream_channel]: https://pub.dev/packages/stream_channel
[stream_transform]: https://pub.dev/packages/stream_transform
[test_api]: https://pub.dev/packages/test_api
[test_core]: https://pub.dev/packages/test_core
[timing]: https://pub.dev/packages/timing
[vm_service_client]: https://pub.dev/packages/vm_service_client
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