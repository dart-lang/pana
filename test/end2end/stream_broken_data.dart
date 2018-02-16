// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/version.dart';
import 'package:test/test.dart';

import 'shared.dart';

final data = new E2EData('stream', '0.7.2+2', _data);

final _data = {
  "panaVersion": panaPkgVersion.toString(),
  "sdkVersion": isSemVer,
  "packageName": "stream",
  "packageVersion": "0.7.2+2",
  "pubspec": {
    "authors": ["Tom Yeh <tomyeh@rikulo.org>"],
    "version": "0.7.2+2",
    "name": "stream",
    "dependencies": {
      "logging": "any",
      "args": "any",
      "rikulo_commons": "any",
      "meta": "any"
    },
    "description":
        "A Dart web server supporting request routing, filtering, template engine, file-based static resources and MVC design pattern.\n",
    "homepage": "http://rikulo.org/projects/stream",
    "documentation": "http://docs.rikulo.org/stream"
  },
  "platform": {"reason": "Error(s) prevent platform classification."},
  "licenses": [
    {"path": "LICENSE", "name": "Apache", "version": "2.0"}
  ],
  "maintenance": {
    "missingChangelog": true,
    "missingExample": true,
    "missingReadme": false,
    "missingAnalysisOptions": true,
    "oldAnalysisOptions": false,
    "strongModeEnabled": false,
    "isExperimentalVersion": true,
    "isPreReleaseVersion": false,
    "errorCount": 0,
    "warningCount": 0,
    "hintCount": 16,
    'suggestions': [
      {
        'level': 'error',
        'title': 'Fix platform conflicts.',
        'description':
            'Make sure none of the libraries use mutually exclusive dependendencies.',
        'penalty': {'amount': 0, 'fraction': 2000}
      },
      {
        'level': 'warning',
        'title': 'Maintain `CHANGELOG.md`.',
        'description':
            'Changelog entries help clients to follow the progress in your code.',
        'penalty': {'amount': 0, 'fraction': 2000}
      },
      {
        'level': 'hint',
        'title': 'Fix issues reported by `dartanalyzer` or `dartfmt`.',
        'description': '`dartanalyzer` or `dartfmt` reported 16 hints.\n\n'
            'Run `dartfmt` to format `lib/plugin.dart`.\n\n'
            'Run `dartfmt` to format `lib/rspc.dart`.\n\n'
            'Similar analysis of the following files failed:\n\n'
            '- `lib/src/connect.dart` (hint)\n'
            '- `lib/src/connect_impl.dart` (hint)\n'
            '- `lib/src/plugin/configurer.dart` (hint)\n'
            '- `lib/src/plugin/loader.dart` (hint)\n'
            '- `lib/src/plugin/router.dart` (hint)\n'
            '- `lib/src/rsp_util.dart` (hint)\n'
            '- `lib/src/rspc/build.dart` (hint)\n'
            '- `lib/src/rspc/compiler.dart` (hint)\n'
            '- `lib/src/rspc/main.dart` (hint)\n'
            '- `lib/src/rspc/tag.dart` (hint)\n'
            '- `lib/src/rspc/tag_util.dart` (hint)\n'
            '- `lib/src/server.dart` (hint)\n'
            '- `lib/src/server_impl.dart` (hint)\n'
            '- `lib/stream.dart` (hint)\n',
        'penalty': {'amount': 16, 'fraction': 0}
      },
      {
        'level': 'hint',
        'title': 'Package is pre-v1 release.',
        'description':
            'While there is nothing inherently wrong with versions of `0.*.*`, it usually means that the author is still experimenting with the general direction API.',
        'penalty': {'amount': 10, 'fraction': 0}
      },
      {
        'level': 'hint',
        'title': 'Maintain an example.',
        'description':
            'None of the files in your `example/` directory matches a known example patterns. Common file name patterns include: `main.dart`, `example.dart` or you could also use `stream.dart`.',
        'penalty': {'amount': 1, 'fraction': 0}
      },
    ],
  },
  "fitness": {"magnitude": 2324.0, "shortcoming": 16.0},
  "suggestions": [
    {
      "level": "error",
      "title": "Make sure `dartfmt` runs.",
      "description":
          startsWith("Running `dartfmt -n .` failed with the following output:")
    },
    {
      "level": "error",
      "title": "Fix dependencies in `pubspec.yaml`.",
      "description":
          "Running `pub upgrade` failed with the following output:\n\n```\nBad state: For args, the parsed version null did not match the locked version 1.3.0.\n```\n"
    },
  ],
  "pkgResolution": null,
  "dartFiles": {
    "bin/packages/args/args.dart": {
      "uri": "asset:stream/bin/packages/args/args.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/args/src/parser.dart": {
      "uri": "asset:stream/bin/packages/args/src/parser.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/args/src/usage.dart": {
      "uri": "asset:stream/bin/packages/args/src/usage.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/js.dart": {
      "uri": "asset:stream/bin/packages/js/js.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/js_wrapping.dart": {
      "uri": "asset:stream/bin/packages/js/js_wrapping.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/src/wrapping/js/array_to_list_adapter.dart": {
      "uri":
          "asset:stream/bin/packages/js/src/wrapping/js/array_to_list_adapter.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/src/wrapping/js/date_to_datetime_adapter.dart": {
      "uri":
          "asset:stream/bin/packages/js/src/wrapping/js/date_to_datetime_adapter.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/src/wrapping/js/object_to_map_adapter.dart": {
      "uri":
          "asset:stream/bin/packages/js/src/wrapping/js/object_to_map_adapter.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/src/wrapping/magic_proxy.dart": {
      "uri": "asset:stream/bin/packages/js/src/wrapping/magic_proxy.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/src/wrapping/translator.dart": {
      "uri": "asset:stream/bin/packages/js/src/wrapping/translator.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/src/wrapping/typed_proxy.dart": {
      "uri": "asset:stream/bin/packages/js/src/wrapping/typed_proxy.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/js/src/wrapping/util.dart": {
      "uri": "asset:stream/bin/packages/js/src/wrapping/util.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/logging/logging.dart": {
      "uri": "asset:stream/bin/packages/logging/logging.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/meta/meta.dart": {
      "uri": "asset:stream/bin/packages/meta/meta.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/async.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/async.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/html.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/html.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/io.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/io.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/js.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/js.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/mirrors.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/mirrors.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/async/stream_provider.dart": {
      "uri":
          "asset:stream/bin/packages/rikulo_commons/src/async/stream_provider.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/async/stream_wrapper.dart": {
      "uri":
          "asset:stream/bin/packages/rikulo_commons/src/async/stream_wrapper.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/html/Browser.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/html/Browser.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/html/Matrix.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/html/Matrix.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/html/Points.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/html/Points.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/html/Size.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/html/Size.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/html/css_util.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/html/css_util.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/html/dom_util.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/html/dom_util.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/io/http_util.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/io/http_util.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/io/http_wrapper.dart": {
      "uri":
          "asset:stream/bin/packages/rikulo_commons/src/io/http_wrapper.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/io/io_util.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/io/io_util.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/io/iosink_wrapper.dart": {
      "uri":
          "asset:stream/bin/packages/rikulo_commons/src/io/iosink_wrapper.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/mirrors/ClassUtil.dart": {
      "uri":
          "asset:stream/bin/packages/rikulo_commons/src/mirrors/ClassUtil.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/mirrors/ObjectUtil.dart": {
      "uri":
          "asset:stream/bin/packages/rikulo_commons/src/mirrors/ObjectUtil.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/mirrors/error.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/mirrors/error.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/util/Color.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/util/Color.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/util/ListUtil.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/util/ListUtil.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/util/MapUtil.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/util/MapUtil.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/util/StringUtil.dart": {
      "uri":
          "asset:stream/bin/packages/rikulo_commons/src/util/StringUtil.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/util/TreeLink.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/util/TreeLink.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/src/util/XmlUtil.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/src/util/XmlUtil.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/rikulo_commons/util.dart": {
      "uri": "asset:stream/bin/packages/rikulo_commons/util.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/plugin.dart": {
      "uri": "asset:stream/bin/packages/stream/plugin.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/rspc.dart": {
      "uri": "asset:stream/bin/packages/stream/rspc.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/connect.dart": {
      "uri": "asset:stream/bin/packages/stream/src/connect.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/connect_impl.dart": {
      "uri": "asset:stream/bin/packages/stream/src/connect_impl.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/plugin/configurer.dart": {
      "uri": "asset:stream/bin/packages/stream/src/plugin/configurer.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/plugin/loader.dart": {
      "uri": "asset:stream/bin/packages/stream/src/plugin/loader.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/plugin/router.dart": {
      "uri": "asset:stream/bin/packages/stream/src/plugin/router.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/rsp_util.dart": {
      "uri": "asset:stream/bin/packages/stream/src/rsp_util.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/rspc/build.dart": {
      "uri": "asset:stream/bin/packages/stream/src/rspc/build.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/rspc/compiler.dart": {
      "uri": "asset:stream/bin/packages/stream/src/rspc/compiler.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/rspc/main.dart": {
      "uri": "asset:stream/bin/packages/stream/src/rspc/main.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/rspc/tag.dart": {
      "uri": "asset:stream/bin/packages/stream/src/rspc/tag.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/rspc/tag_util.dart": {
      "uri": "asset:stream/bin/packages/stream/src/rspc/tag_util.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/server.dart": {
      "uri": "asset:stream/bin/packages/stream/src/server.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/src/server_impl.dart": {
      "uri": "asset:stream/bin/packages/stream/src/server_impl.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/stream/stream.dart": {
      "uri": "asset:stream/bin/packages/stream/stream.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/compact_vm_config.dart": {
      "uri": "asset:stream/bin/packages/unittest/compact_vm_config.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/html_config.dart": {
      "uri": "asset:stream/bin/packages/unittest/html_config.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/html_enhanced_config.dart": {
      "uri": "asset:stream/bin/packages/unittest/html_enhanced_config.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/html_individual_config.dart": {
      "uri": "asset:stream/bin/packages/unittest/html_individual_config.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/interactive_html_config.dart": {
      "uri": "asset:stream/bin/packages/unittest/interactive_html_config.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/matcher.dart": {
      "uri": "asset:stream/bin/packages/unittest/matcher.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/mock.dart": {
      "uri": "asset:stream/bin/packages/unittest/mock.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/basematcher.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/basematcher.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/config.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/config.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/core_matchers.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/core_matchers.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/description.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/description.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/expect.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/expect.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/future_matchers.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/future_matchers.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/interfaces.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/interfaces.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/iterable_matchers.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/iterable_matchers.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/map_matchers.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/map_matchers.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/numeric_matchers.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/numeric_matchers.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/operator_matchers.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/operator_matchers.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/string_matchers.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/string_matchers.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/src/test_case.dart": {
      "uri": "asset:stream/bin/packages/unittest/src/test_case.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/unittest.dart": {
      "uri": "asset:stream/bin/packages/unittest/unittest.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/packages/unittest/vm_config.dart": {
      "uri": "asset:stream/bin/packages/unittest/vm_config.dart",
      "size": null,
      "isFormatted": null,
      "codeProblems": null
    },
    "bin/rspc.dart": {
      "uri": "asset:stream/bin/rspc.dart",
      "size": 267,
      "isFormatted": null,
      "codeProblems": null
    },
    "lib/plugin.dart": {
      "uri": "package:stream/plugin.dart",
      "size": 515,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 13.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/plugin.dart`.',
            'description': 'Run `dartfmt` to format `lib/plugin.dart`.',
            'file': 'lib/plugin.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/rspc.dart": {
      "uri": "package:stream/rspc.dart",
      "size": 551,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 14.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/rspc.dart`.',
            'description': 'Run `dartfmt` to format `lib/rspc.dart`.',
            'file': 'lib/rspc.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/connect.dart": {
      "uri": "package:stream/src/connect.dart",
      "size": 13038,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 242.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/connect.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/connect.dart`.',
            'file': 'lib/src/connect.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/connect_impl.dart": {
      "uri": "package:stream/src/connect_impl.dart",
      "size": 6339,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 139.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/connect_impl.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/connect_impl.dart`.',
            'file': 'lib/src/connect_impl.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/plugin/configurer.dart": {
      "uri": "package:stream/src/plugin/configurer.dart",
      "size": 857,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 19.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/plugin/configurer.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/plugin/configurer.dart`.',
            'file': 'lib/src/plugin/configurer.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/plugin/loader.dart": {
      "uri": "package:stream/src/plugin/loader.dart",
      "size": 2292,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 51.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/plugin/loader.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/plugin/loader.dart`.',
            'file': 'lib/src/plugin/loader.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/plugin/router.dart": {
      "uri": "package:stream/src/plugin/router.dart",
      "size": 12512,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 280.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/plugin/router.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/plugin/router.dart`.',
            'file': 'lib/src/plugin/router.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/rsp_util.dart": {
      "uri": "package:stream/src/rsp_util.dart",
      "size": 1245,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 26.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/rsp_util.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/rsp_util.dart`.',
            'file': 'lib/src/rsp_util.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/rspc/build.dart": {
      "uri": "package:stream/src/rspc/build.dart",
      "size": 5338,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 109.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/rspc/build.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/rspc/build.dart`.',
            'file': 'lib/src/rspc/build.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/rspc/compiler.dart": {
      "uri": "package:stream/src/rspc/compiler.dart",
      "size": 25116,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 595.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/rspc/compiler.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/rspc/compiler.dart`.',
            'file': 'lib/src/rspc/compiler.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/rspc/main.dart": {
      "uri": "package:stream/src/rspc/main.dart",
      "size": 1855,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 46.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/rspc/main.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/rspc/main.dart`.',
            'file': 'lib/src/rspc/main.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/rspc/tag.dart": {
      "uri": "package:stream/src/rspc/tag.dart",
      "size": 11243,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 271.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/rspc/tag.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/rspc/tag.dart`.',
            'file': 'lib/src/rspc/tag.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/rspc/tag_util.dart": {
      "uri": "package:stream/src/rspc/tag_util.dart",
      "size": 4565,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 106.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/rspc/tag_util.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/rspc/tag_util.dart`.',
            'file': 'lib/src/rspc/tag_util.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/server.dart": {
      "uri": "package:stream/src/server.dart",
      "size": 10258,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 174.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/server.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/server.dart`.',
            'file': 'lib/src/server.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/src/server_impl.dart": {
      "uri": "package:stream/src/server_impl.dart",
      "size": 9758,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 221.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/server_impl.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/server_impl.dart`.',
            'file': 'lib/src/server_impl.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    },
    "lib/stream.dart": {
      "uri": "package:stream/stream.dart",
      "size": 695,
      "isFormatted": null,
      "codeProblems": null,
      "fitness": {
        "magnitude": 18.0,
        "shortcoming": 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/stream.dart`.',
            'description': 'Run `dartfmt` to format `lib/stream.dart`.',
            'file': 'lib/stream.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      }
    }
  }
};
