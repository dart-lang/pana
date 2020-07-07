## 5/20 Packaging conventions

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

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/model/collection/list_tracker.dart`
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

To reproduce make sure you are using [pedantic](https://pub.dev/packages/pedantic#using-the-lints) and run `dartanalyzer lib/src/model/selection/noop_selection_model_impl.dart`
</details>

## 10/30 Package is a good, trustworthy dependency

### [*] 10/10 points: All of the package dependencies are supported in the latest version

<details>
<summary>
Dependencies
</summary>

|Package|Constraint|Compatible|Latest|
|:-|:-|:-|:-|
|[angular]|^5.1.0|5.3.1|5.3.1|
|[angular_forms]|^2.1.0|2.1.2|2.1.4|
|[async]|^2.0.8|2.4.2|2.4.2|
|[build]|>=0.11.1 <2.0.0|1.3.0|1.3.0|
|[build_config]|>=0.2.6 <0.4.0|0.3.2|0.4.2|
|[built_collection]|^4.0.0|4.3.2|4.3.2|
|[collection]|^1.14.10|1.14.13|1.14.13|
|[fixnum]|^0.10.7|0.10.11|0.10.11|
|[intl]|>=0.14.0 <0.16.0|0.15.8|0.16.1|
|[js]|^0.6.1|0.6.2|0.6.2|
|[logging]|^0.11.2|0.11.4|0.11.4|
|[meta]|^1.0.4|1.2.1|1.2.1|
|[observable]|^0.22.1+3|0.22.2|0.22.2|
|[protobuf]|^0.10.2|0.10.8|1.0.1|
|[quiver]|>=0.24.0 <0.30.0|0.29.0+2|2.1.3|
|[sass_builder]|^2.0.2|2.1.3|2.1.3|
|**Transitive dependencies**|
|[analyzer]|-|0.39.12|0.39.12|
|[angular_ast]|-|0.5.11|0.5.11|
|[angular_compiler]|-|0.4.5|0.4.5|
|[args]|-|1.6.0|1.6.0|
|[built_value]|-|7.1.0|7.1.0|
|[charcode]|-|1.1.3|1.1.3|
|[checked_yaml]|-|1.0.2|1.0.2|
|[cli_repl]|-|0.2.0+1|0.2.0+1|
|[code_builder]|-|3.3.0|3.3.0|
|[convert]|-|2.1.1|2.1.1|
|[crypto]|-|2.1.5|2.1.5|
|[csslib]|-|0.16.1|0.16.1|
|[dart2_constant]|-|1.0.2+dart2|1.0.2+dart2|
|[dart_internal]|-|0.1.9|0.1.9|
|[dart_style]|-|1.3.6|1.3.6|
|[front_end]|-|0.1.29|0.1.29|
|[glob]|-|1.2.0|1.2.0|
|[html]|-|0.14.0+3|0.14.0+3|
|[http]|-|0.12.1|0.12.1|
|[http_parser]|-|3.1.4|3.1.4|
|[json_annotation]|-|3.0.1|3.0.1|
|[kernel]|-|0.3.29|0.3.29|
|[matcher]|-|0.12.8|0.12.8|
|[node_interop]|-|1.1.1|1.1.1|
|[node_io]|-|1.1.1|1.1.1|
|[package_config]|-|1.9.3|1.9.3|
|[package_resolver]|-|1.0.10|1.0.10|
|[pedantic]|-|1.9.1|1.9.1|
|[pub_semver]|-|1.4.4|1.4.4|
|[pubspec_parse]|-|0.1.5|0.1.5|
|[sass]|-|1.26.10|1.26.10|
|[source_gen]|-|0.9.5|0.9.5|
|[source_maps]|-|0.10.9|0.10.9|
|[source_span]|-|1.7.0|1.7.0|
|[stack_trace]|-|1.9.5|1.9.5|
|[stream_transform]|-|1.2.0|1.2.0|
|[string_scanner]|-|1.0.5|1.0.5|
|[term_glyph]|-|1.1.0|1.1.0|
|[tuple]|-|1.0.3|1.0.3|
|[typed_data]|-|1.2.0|1.2.0|
|[watcher]|-|0.9.7+15|0.9.7+15|
|[yaml]|-|2.2.1|2.2.1|
|[boolean_selector]|-|2.0.0|2.0.0|
|[http_multi_server]|-|2.2.0|2.2.0|
|[io]|-|0.3.4|0.3.4|
|[json_rpc_2]|-|2.2.1|2.2.1|
|[mime]|-|0.9.6+3|0.9.6+3|
|[multi_server_socket]|-|1.0.2|1.0.2|
|[node_preamble]|-|1.4.12|1.4.12|
|[pool]|-|1.4.0|1.4.0|
|[shelf]|-|0.7.7|0.7.7|
|[shelf_packages_handler]|-|2.0.0|2.0.0|
|[shelf_static]|-|0.2.8|0.2.8|
|[shelf_web_socket]|-|0.2.3|0.2.3|
|[source_map_stack_trace]|-|2.0.0|2.0.0|
|[stream_channel]|-|2.0.0|2.0.0|
|[test_api]|-|0.2.17|0.2.17|
|[test_core]|-|0.3.10|0.3.10|
|[vm_service_client]|-|0.2.6+3|0.2.6+3|
|[web_socket_channel]|-|1.1.0|1.1.0|

To reproduce run `pub outdated --no-dev-dependencies --up-to-date`.

[angular]: https://pub.dev/packages/angular
[angular_forms]: https://pub.dev/packages/angular_forms
[async]: https://pub.dev/packages/async
[build]: https://pub.dev/packages/build
[build_config]: https://pub.dev/packages/build_config
[built_collection]: https://pub.dev/packages/built_collection
[collection]: https://pub.dev/packages/collection
[fixnum]: https://pub.dev/packages/fixnum
[intl]: https://pub.dev/packages/intl
[js]: https://pub.dev/packages/js
[logging]: https://pub.dev/packages/logging
[meta]: https://pub.dev/packages/meta
[observable]: https://pub.dev/packages/observable
[protobuf]: https://pub.dev/packages/protobuf
[quiver]: https://pub.dev/packages/quiver
[sass_builder]: https://pub.dev/packages/sass_builder
[analyzer]: https://pub.dev/packages/analyzer
[angular_ast]: https://pub.dev/packages/angular_ast
[angular_compiler]: https://pub.dev/packages/angular_compiler
[args]: https://pub.dev/packages/args
[built_value]: https://pub.dev/packages/built_value
[charcode]: https://pub.dev/packages/charcode
[checked_yaml]: https://pub.dev/packages/checked_yaml
[cli_repl]: https://pub.dev/packages/cli_repl
[code_builder]: https://pub.dev/packages/code_builder
[convert]: https://pub.dev/packages/convert
[crypto]: https://pub.dev/packages/crypto
[csslib]: https://pub.dev/packages/csslib
[dart2_constant]: https://pub.dev/packages/dart2_constant
[dart_internal]: https://pub.dev/packages/dart_internal
[dart_style]: https://pub.dev/packages/dart_style
[front_end]: https://pub.dev/packages/front_end
[glob]: https://pub.dev/packages/glob
[html]: https://pub.dev/packages/html
[http]: https://pub.dev/packages/http
[http_parser]: https://pub.dev/packages/http_parser
[json_annotation]: https://pub.dev/packages/json_annotation
[kernel]: https://pub.dev/packages/kernel
[matcher]: https://pub.dev/packages/matcher
[node_interop]: https://pub.dev/packages/node_interop
[node_io]: https://pub.dev/packages/node_io
[package_config]: https://pub.dev/packages/package_config
[package_resolver]: https://pub.dev/packages/package_resolver
[pedantic]: https://pub.dev/packages/pedantic
[pub_semver]: https://pub.dev/packages/pub_semver
[pubspec_parse]: https://pub.dev/packages/pubspec_parse
[sass]: https://pub.dev/packages/sass
[source_gen]: https://pub.dev/packages/source_gen
[source_maps]: https://pub.dev/packages/source_maps
[source_span]: https://pub.dev/packages/source_span
[stack_trace]: https://pub.dev/packages/stack_trace
[stream_transform]: https://pub.dev/packages/stream_transform
[string_scanner]: https://pub.dev/packages/string_scanner
[term_glyph]: https://pub.dev/packages/term_glyph
[tuple]: https://pub.dev/packages/tuple
[typed_data]: https://pub.dev/packages/typed_data
[watcher]: https://pub.dev/packages/watcher
[yaml]: https://pub.dev/packages/yaml
[boolean_selector]: https://pub.dev/packages/boolean_selector
[http_multi_server]: https://pub.dev/packages/http_multi_server
[io]: https://pub.dev/packages/io
[json_rpc_2]: https://pub.dev/packages/json_rpc_2
[mime]: https://pub.dev/packages/mime
[multi_server_socket]: https://pub.dev/packages/multi_server_socket
[node_preamble]: https://pub.dev/packages/node_preamble
[pool]: https://pub.dev/packages/pool
[shelf]: https://pub.dev/packages/shelf
[shelf_packages_handler]: https://pub.dev/packages/shelf_packages_handler
[shelf_static]: https://pub.dev/packages/shelf_static
[shelf_web_socket]: https://pub.dev/packages/shelf_web_socket
[source_map_stack_trace]: https://pub.dev/packages/source_map_stack_trace
[stream_channel]: https://pub.dev/packages/stream_channel
[test_api]: https://pub.dev/packages/test_api
[test_core]: https://pub.dev/packages/test_core
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