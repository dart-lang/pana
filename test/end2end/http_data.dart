// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:pana/src/version.dart';

import 'shared.dart';

final data = new E2EData('http', '0.11.3+13', _data);

final _data = {
  "panaVersion": panaPkgVersion.toString(),
  "sdkVersion": isSemVer,
  "packageName": "http",
  "packageVersion": "0.11.3+13",
  "pubspec": {
    "author": "Dart Team <misc@dartlang.org>",
    "dependencies": {
      "async": "^1.10.0",
      "collection": "^1.5.0",
      "http_parser": ">=0.0.1 <4.0.0",
      "path": ">=0.9.0 <2.0.0",
      "stack_trace": ">=0.9.1 <2.0.0"
    },
    "description": "A composable, Future-based API for making HTTP requests.",
    "dev_dependencies": {"unittest": ">=0.9.0 <0.12.0"},
    "environment": {"sdk": ">=1.23.0-dev.0.0 <2.0.0"},
    "homepage": "https://github.com/dart-lang/http",
    "name": "http",
    "version": "0.11.3+13",
  },
  "pkgResolution": {
    "dependencies": [
      {
        "package": "async",
        "dependencyType": "direct",
        "constraintType": "normal",
        "constraint": "^1.10.0",
        "resolved": isNotNull,
        "available": isNotNull,
      },
      {
        "package": "charcode",
        "dependencyType": "transitive",
        "constraintType": "inherited",
        "resolved": isNotNull,
      },
      {
        "package": "collection",
        "dependencyType": "direct",
        "constraintType": "normal",
        "constraint": "^1.5.0",
        "resolved": isNotNull,
      },
      {
        "package": "http_parser",
        "dependencyType": "direct",
        "constraintType": "normal",
        "constraint": ">=0.0.1 <4.0.0",
        "resolved": isNotNull,
      },
      {
        "package": "path",
        "dependencyType": "direct",
        "constraintType": "normal",
        "constraint": ">=0.9.0 <2.0.0",
        "resolved": isNotNull,
      },
      {
        "package": "source_span",
        "dependencyType": "transitive",
        "constraintType": "inherited",
        "resolved": isNotNull,
      },
      {
        "package": "stack_trace",
        "dependencyType": "direct",
        "constraintType": "normal",
        "constraint": ">=0.9.1 <2.0.0",
        "resolved": isNotNull,
      },
      {
        "package": "string_scanner",
        "dependencyType": "transitive",
        "constraintType": "inherited",
        "resolved": isNotNull,
      },
      {
        "package": "typed_data",
        "dependencyType": "transitive",
        "constraintType": "inherited",
        "resolved": isNotNull,
      },
      {
        "package": "unittest",
        "dependencyType": "dev",
        "constraintType": "normal",
        "constraint": ">=0.9.0 <0.12.0",
      }
    ]
  },
  "dartFiles": {
    "lib/browser_client.dart": {
      "uri": "package:http/browser_client.dart",
      "size": 3688,
      "isFormatted": false,
      "codeProblems": [],
      "directLibs": [
        "dart:async",
        "dart:html",
        "dart:typed_data",
        "package:http/src/base_client.dart",
        "package:http/src/base_request.dart",
        "package:http/src/byte_stream.dart",
        "package:http/src/exception.dart",
        "package:http/src/streamed_response.dart",
        "package:stack_trace/stack_trace.dart",
      ],
      "transitiveLibs": [
        "dart-pana:web_safe_io",
        "dart:async",
        "dart:collection",
        "dart:convert",
        "dart:html",
        "dart:math",
        "dart:typed_data",
        "package:async/async.dart",
        "package:async/src/async_cache.dart",
        "package:async/src/async_memoizer.dart",
        "package:async/src/byte_collector.dart",
        "package:async/src/cancelable_operation.dart",
        "package:async/src/delegate/event_sink.dart",
        "package:async/src/delegate/future.dart",
        "package:async/src/delegate/sink.dart",
        "package:async/src/delegate/stream.dart",
        "package:async/src/delegate/stream_consumer.dart",
        "package:async/src/delegate/stream_sink.dart",
        "package:async/src/delegate/stream_subscription.dart",
        "package:async/src/future_group.dart",
        "package:async/src/lazy_stream.dart",
        "package:async/src/null_stream_sink.dart",
        "package:async/src/restartable_timer.dart",
        "package:async/src/result.dart",
        "package:async/src/result/capture_sink.dart",
        "package:async/src/result/capture_transformer.dart",
        "package:async/src/result/error.dart",
        "package:async/src/result/future.dart",
        "package:async/src/result/release_sink.dart",
        "package:async/src/result/release_transformer.dart",
        "package:async/src/result/value.dart",
        "package:async/src/single_subscription_transformer.dart",
        "package:async/src/stream_completer.dart",
        "package:async/src/stream_group.dart",
        "package:async/src/stream_queue.dart",
        "package:async/src/stream_sink_completer.dart",
        "package:async/src/stream_sink_transformer.dart",
        "package:async/src/stream_sink_transformer/handler_transformer.dart",
        "package:async/src/stream_sink_transformer/stream_transformer_wrapper.dart",
        "package:async/src/stream_sink_transformer/typed.dart",
        "package:async/src/stream_splitter.dart",
        "package:async/src/stream_subscription_transformer.dart",
        "package:async/src/stream_zip.dart",
        "package:async/src/subscription_stream.dart",
        "package:async/src/typed/future.dart",
        "package:async/src/typed/stream.dart",
        "package:async/src/typed/stream_subscription.dart",
        "package:async/src/typed_stream_transformer.dart",
        "package:async/src/utils.dart",
        "package:charcode/ascii.dart",
        "package:charcode/charcode.dart",
        "package:charcode/html_entity.dart",
        "package:collection/collection.dart",
        "package:collection/src/algorithms.dart",
        "package:collection/src/canonicalized_map.dart",
        "package:collection/src/combined_wrappers/combined_iterable.dart",
        "package:collection/src/combined_wrappers/combined_list.dart",
        "package:collection/src/combined_wrappers/combined_map.dart",
        "package:collection/src/comparators.dart",
        "package:collection/src/empty_unmodifiable_set.dart",
        "package:collection/src/equality.dart",
        "package:collection/src/equality_map.dart",
        "package:collection/src/equality_set.dart",
        "package:collection/src/functions.dart",
        "package:collection/src/iterable_zip.dart",
        "package:collection/src/priority_queue.dart",
        "package:collection/src/queue_list.dart",
        "package:collection/src/typed_wrappers.dart",
        "package:collection/src/union_set.dart",
        "package:collection/src/union_set_controller.dart",
        "package:collection/src/unmodifiable_wrappers.dart",
        "package:collection/src/utils.dart",
        "package:collection/src/wrappers.dart",
        "package:http/src/base_client.dart",
        "package:http/src/base_request.dart",
        "package:http/src/base_response.dart",
        "package:http/src/byte_stream.dart",
        "package:http/src/client.dart",
        "package:http/src/exception.dart",
        "package:http/src/io_client.dart",
        "package:http/src/request.dart",
        "package:http/src/response.dart",
        "package:http/src/streamed_response.dart",
        "package:http/src/utils.dart",
        "package:http_parser/http_parser.dart",
        "package:http_parser/src/authentication_challenge.dart",
        "package:http_parser/src/case_insensitive_map.dart",
        "package:http_parser/src/chunked_coding.dart",
        "package:http_parser/src/chunked_coding/decoder.dart",
        "package:http_parser/src/chunked_coding/encoder.dart",
        "package:http_parser/src/http_date.dart",
        "package:http_parser/src/media_type.dart",
        "package:http_parser/src/scan.dart",
        "package:http_parser/src/utils.dart",
        "package:path/path.dart",
        "package:path/src/characters.dart",
        "package:path/src/context.dart",
        "package:path/src/internal_style.dart",
        "package:path/src/parsed_path.dart",
        "package:path/src/path_exception.dart",
        "package:path/src/style.dart",
        "package:path/src/style/posix.dart",
        "package:path/src/style/url.dart",
        "package:path/src/style/windows.dart",
        "package:path/src/utils.dart",
        "package:source_span/source_span.dart",
        "package:source_span/src/colors.dart",
        "package:source_span/src/file.dart",
        "package:source_span/src/location.dart",
        "package:source_span/src/location_mixin.dart",
        "package:source_span/src/span.dart",
        "package:source_span/src/span_exception.dart",
        "package:source_span/src/span_mixin.dart",
        "package:source_span/src/span_with_context.dart",
        "package:source_span/src/utils.dart",
        "package:stack_trace/src/chain.dart",
        "package:stack_trace/src/frame.dart",
        "package:stack_trace/src/lazy_chain.dart",
        "package:stack_trace/src/lazy_trace.dart",
        "package:stack_trace/src/stack_zone_specification.dart",
        "package:stack_trace/src/trace.dart",
        "package:stack_trace/src/unparsed_frame.dart",
        "package:stack_trace/src/utils.dart",
        "package:stack_trace/src/vm_trace.dart",
        "package:stack_trace/stack_trace.dart",
        "package:string_scanner/src/eager_span_scanner.dart",
        "package:string_scanner/src/exception.dart",
        "package:string_scanner/src/line_scanner.dart",
        "package:string_scanner/src/relative_span_scanner.dart",
        "package:string_scanner/src/span_scanner.dart",
        "package:string_scanner/src/string_scanner.dart",
        "package:string_scanner/src/utils.dart",
        "package:string_scanner/string_scanner.dart",
        "package:typed_data/typed_buffers.dart",
        "package:typed_data/typed_data.dart",
      ],
      'platform': {
        'components': ['html'],
        'uses': {'flutter': 'forbidden', 'web': 'used', 'other': 'forbidden'},
      },
      'fitness': {
        'magnitude': 83.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/browser_client.dart`.',
            'description': 'Run `dartfmt` to format `lib/browser_client.dart`.',
            'file': 'lib/browser_client.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/http.dart": {
      "uri": "package:http/http.dart",
      "size": 7234,
      "isFormatted": false,
      "codeProblems": [
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/http.dart',
          'line': 64,
          'col': 29,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/http.dart',
          'line': 88,
          'col': 29,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/http.dart',
          'line': 112,
          'col': 29,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        }
      ],
      "directLibs": [
        "dart:async",
        "dart:convert",
        "dart:typed_data",
        "package:http/src/base_client.dart",
        "package:http/src/base_request.dart",
        "package:http/src/base_response.dart",
        "package:http/src/byte_stream.dart",
        "package:http/src/client.dart",
        "package:http/src/exception.dart",
        "package:http/src/io_client.dart",
        "package:http/src/multipart_file.dart",
        "package:http/src/multipart_request.dart",
        "package:http/src/request.dart",
        "package:http/src/response.dart",
        "package:http/src/streamed_request.dart",
        "package:http/src/streamed_response.dart",
      ],
      "transitiveLibs": [
        "dart-pana:web_safe_io",
        "dart:async",
        "dart:collection",
        "dart:convert",
        "dart:math",
        "dart:typed_data",
        "package:async/async.dart",
        "package:async/src/async_cache.dart",
        "package:async/src/async_memoizer.dart",
        "package:async/src/byte_collector.dart",
        "package:async/src/cancelable_operation.dart",
        "package:async/src/delegate/event_sink.dart",
        "package:async/src/delegate/future.dart",
        "package:async/src/delegate/sink.dart",
        "package:async/src/delegate/stream.dart",
        "package:async/src/delegate/stream_consumer.dart",
        "package:async/src/delegate/stream_sink.dart",
        "package:async/src/delegate/stream_subscription.dart",
        "package:async/src/future_group.dart",
        "package:async/src/lazy_stream.dart",
        "package:async/src/null_stream_sink.dart",
        "package:async/src/restartable_timer.dart",
        "package:async/src/result.dart",
        "package:async/src/result/capture_sink.dart",
        "package:async/src/result/capture_transformer.dart",
        "package:async/src/result/error.dart",
        "package:async/src/result/future.dart",
        "package:async/src/result/release_sink.dart",
        "package:async/src/result/release_transformer.dart",
        "package:async/src/result/value.dart",
        "package:async/src/single_subscription_transformer.dart",
        "package:async/src/stream_completer.dart",
        "package:async/src/stream_group.dart",
        "package:async/src/stream_queue.dart",
        "package:async/src/stream_sink_completer.dart",
        "package:async/src/stream_sink_transformer.dart",
        "package:async/src/stream_sink_transformer/handler_transformer.dart",
        "package:async/src/stream_sink_transformer/stream_transformer_wrapper.dart",
        "package:async/src/stream_sink_transformer/typed.dart",
        "package:async/src/stream_splitter.dart",
        "package:async/src/stream_subscription_transformer.dart",
        "package:async/src/stream_zip.dart",
        "package:async/src/subscription_stream.dart",
        "package:async/src/typed/future.dart",
        "package:async/src/typed/stream.dart",
        "package:async/src/typed/stream_subscription.dart",
        "package:async/src/typed_stream_transformer.dart",
        "package:async/src/utils.dart",
        "package:charcode/ascii.dart",
        "package:charcode/charcode.dart",
        "package:charcode/html_entity.dart",
        "package:collection/collection.dart",
        "package:collection/src/algorithms.dart",
        "package:collection/src/canonicalized_map.dart",
        "package:collection/src/combined_wrappers/combined_iterable.dart",
        "package:collection/src/combined_wrappers/combined_list.dart",
        "package:collection/src/combined_wrappers/combined_map.dart",
        "package:collection/src/comparators.dart",
        "package:collection/src/empty_unmodifiable_set.dart",
        "package:collection/src/equality.dart",
        "package:collection/src/equality_map.dart",
        "package:collection/src/equality_set.dart",
        "package:collection/src/functions.dart",
        "package:collection/src/iterable_zip.dart",
        "package:collection/src/priority_queue.dart",
        "package:collection/src/queue_list.dart",
        "package:collection/src/typed_wrappers.dart",
        "package:collection/src/union_set.dart",
        "package:collection/src/union_set_controller.dart",
        "package:collection/src/unmodifiable_wrappers.dart",
        "package:collection/src/utils.dart",
        "package:collection/src/wrappers.dart",
        "package:http/src/base_client.dart",
        "package:http/src/base_request.dart",
        "package:http/src/base_response.dart",
        "package:http/src/boundary_characters.dart",
        "package:http/src/byte_stream.dart",
        "package:http/src/client.dart",
        "package:http/src/exception.dart",
        "package:http/src/io_client.dart",
        "package:http/src/multipart_file.dart",
        "package:http/src/multipart_request.dart",
        "package:http/src/request.dart",
        "package:http/src/response.dart",
        "package:http/src/streamed_request.dart",
        "package:http/src/streamed_response.dart",
        "package:http/src/utils.dart",
        "package:http_parser/http_parser.dart",
        "package:http_parser/src/authentication_challenge.dart",
        "package:http_parser/src/case_insensitive_map.dart",
        "package:http_parser/src/chunked_coding.dart",
        "package:http_parser/src/chunked_coding/decoder.dart",
        "package:http_parser/src/chunked_coding/encoder.dart",
        "package:http_parser/src/http_date.dart",
        "package:http_parser/src/media_type.dart",
        "package:http_parser/src/scan.dart",
        "package:http_parser/src/utils.dart",
        "package:path/path.dart",
        "package:path/src/characters.dart",
        "package:path/src/context.dart",
        "package:path/src/internal_style.dart",
        "package:path/src/parsed_path.dart",
        "package:path/src/path_exception.dart",
        "package:path/src/style.dart",
        "package:path/src/style/posix.dart",
        "package:path/src/style/url.dart",
        "package:path/src/style/windows.dart",
        "package:path/src/utils.dart",
        "package:source_span/source_span.dart",
        "package:source_span/src/colors.dart",
        "package:source_span/src/file.dart",
        "package:source_span/src/location.dart",
        "package:source_span/src/location_mixin.dart",
        "package:source_span/src/span.dart",
        "package:source_span/src/span_exception.dart",
        "package:source_span/src/span_mixin.dart",
        "package:source_span/src/span_with_context.dart",
        "package:source_span/src/utils.dart",
        "package:string_scanner/src/eager_span_scanner.dart",
        "package:string_scanner/src/exception.dart",
        "package:string_scanner/src/line_scanner.dart",
        "package:string_scanner/src/relative_span_scanner.dart",
        "package:string_scanner/src/span_scanner.dart",
        "package:string_scanner/src/string_scanner.dart",
        "package:string_scanner/src/utils.dart",
        "package:string_scanner/string_scanner.dart",
        "package:typed_data/typed_buffers.dart",
        "package:typed_data/typed_data.dart",
      ],
      'platform': {
        'components': [],
        'uses': {'flutter': 'allowed', 'web': 'allowed', 'other': 'allowed'},
      },
      'fitness': {
        'magnitude': 139.0,
        'shortcoming': 4.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/http.dart`.',
            'description': 'Run `dartfmt` to format `lib/http.dart`.',
            'file': 'lib/http.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/http.dart`.',
            'description':
                'Strong-mode analysis of `lib/http.dart` gave the following hint:\n'
                '\n'
                'line: 64 col: 29  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/http.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/http.dart`.',
            'description':
                'Strong-mode analysis of `lib/http.dart` gave the following hint:\n'
                '\n'
                'line: 88 col: 29  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/http.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/http.dart`.',
            'description':
                'Strong-mode analysis of `lib/http.dart` gave the following hint:\n'
                '\n'
                'line: 112 col: 29  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/http.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
        ],
      },
    },
    "lib/src/base_client.dart": {
      "uri": "package:http/src/base_client.dart",
      "size": 7821,
      "isFormatted": false,
      "codeProblems": [],
      'fitness': {
        'magnitude': 136.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/base_client.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/base_client.dart`.',
            'file': 'lib/src/base_client.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/src/base_request.dart": {
      "uri": "package:http/src/base_request.dart",
      "size": 4739,
      "isFormatted": false,
      "codeProblems": [],
      'fitness': {
        'magnitude': 93.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/base_request.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/base_request.dart`.',
            'file': 'lib/src/base_request.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/src/base_response.dart": {
      "uri": "package:http/src/base_response.dart",
      "size": 1727,
      "isFormatted": false,
      "codeProblems": [],
      'fitness': {
        'magnitude': 32.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/base_response.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/base_response.dart`.',
            'file': 'lib/src/base_response.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/src/boundary_characters.dart": {
      "uri": "package:http/src/boundary_characters.dart",
      "size": 957,
      "isFormatted": false,
      "codeProblems": [],
      'fitness': {
        'magnitude': 13.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/boundary_characters.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/boundary_characters.dart`.',
            'file': 'lib/src/boundary_characters.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/src/byte_stream.dart": {
      "uri": "package:http/src/byte_stream.dart",
      "size": 1391,
      "isFormatted": false,
      "codeProblems": [
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/byte_stream.dart',
          'line': 31,
          'col': 51,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/byte_stream.dart',
          'line': 34,
          'col': 52,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        }
      ],
      'fitness': {
        'magnitude': 25.0,
        'shortcoming': 3.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/byte_stream.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/byte_stream.dart`.',
            'file': 'lib/src/byte_stream.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/byte_stream.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/byte_stream.dart` gave the following hint:\n'
                '\n'
                'line: 31 col: 51  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/byte_stream.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/byte_stream.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/byte_stream.dart` gave the following hint:\n'
                '\n'
                'line: 34 col: 52  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/byte_stream.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
        ],
      },
    },
    "lib/src/client.dart": {
      "uri": "package:http/src/client.dart",
      "size": 6152,
      "isFormatted": false,
      "codeProblems": [
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/client.dart',
          'line': 59,
          'col': 31,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/client.dart',
          'line': 80,
          'col': 31,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/client.dart',
          'line': 101,
          'col': 31,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        }
      ],
      'fitness': {
        'magnitude': 101.0,
        'shortcoming': 4.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/client.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/client.dart`.',
            'file': 'lib/src/client.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/client.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/client.dart` gave the following hint:\n'
                '\n'
                'line: 59 col: 31  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/client.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/client.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/client.dart` gave the following hint:\n'
                '\n'
                'line: 80 col: 31  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/client.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/client.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/client.dart` gave the following hint:\n'
                '\n'
                'line: 101 col: 31  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/client.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
        ],
      },
    },
    "lib/src/exception.dart": {
      "uri": "package:http/src/exception.dart",
      "size": 502,
      "isFormatted": true,
      "codeProblems": [],
      'fitness': {'magnitude': 9.0, 'shortcoming': 0.0},
    },
    "lib/src/io_client.dart": {
      "uri": "package:http/src/io_client.dart",
      "size": 2530,
      "isFormatted": false,
      "codeProblems": [],
      'fitness': {
        'magnitude': 49.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/io_client.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/io_client.dart`.',
            'file': 'lib/src/io_client.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/src/mock_client.dart": {
      "uri": "package:http/src/mock_client.dart",
      "size": 3320,
      "isFormatted": false,
      "codeProblems": [],
      'fitness': {
        'magnitude': 59.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/mock_client.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/mock_client.dart`.',
            'file': 'lib/src/mock_client.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/src/multipart_file.dart": {
      "uri": "package:http/src/multipart_file.dart",
      "size": 4431,
      "isFormatted": false,
      "codeProblems": [
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/multipart_file.dart',
          'line': 73,
          'col': 74,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        }
      ],
      'fitness': {
        'magnitude': 79.0,
        'shortcoming': 2.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/multipart_file.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/multipart_file.dart`.',
            'file': 'lib/src/multipart_file.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/multipart_file.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/multipart_file.dart` gave the following hint:\n'
                '\n'
                'line: 73 col: 74  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/multipart_file.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
        ],
      },
    },
    "lib/src/multipart_request.dart": {
      "uri": "package:http/src/multipart_request.dart",
      "size": 5905,
      "isFormatted": false,
      "codeProblems": [
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/multipart_request.dart',
          'line': 64,
          'col': 11,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/multipart_request.dart',
          'line': 65,
          'col': 11,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/multipart_request.dart',
          'line': 70,
          'col': 11,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/multipart_request.dart',
          'line': 93,
          'col': 22,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/multipart_request.dart',
          'line': 96,
          'col': 48,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        }
      ],
      'fitness': {
        'magnitude': 116.0,
        'shortcoming': 6.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/multipart_request.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/multipart_request.dart`.',
            'file': 'lib/src/multipart_request.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/multipart_request.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/multipart_request.dart` gave the following hint:\n'
                '\n'
                'line: 64 col: 11  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/multipart_request.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/multipart_request.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/multipart_request.dart` gave the following hint:\n'
                '\n'
                'line: 65 col: 11  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/multipart_request.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/multipart_request.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/multipart_request.dart` gave the following hint:\n'
                '\n'
                'line: 70 col: 11  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/multipart_request.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/multipart_request.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/multipart_request.dart` gave the following hint:\n'
                '\n'
                'line: 93 col: 22  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/multipart_request.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/multipart_request.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/multipart_request.dart` gave the following hint:\n'
                '\n'
                'line: 96 col: 48  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/multipart_request.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
        ],
      },
    },
    "lib/src/request.dart": {
      "uri": "package:http/src/request.dart",
      "size": 5952,
      "isFormatted": false,
      "codeProblems": [
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/request.dart',
          'line': 39,
          'col': 42,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/request.dart',
          'line': 133,
          'col': 26,
          'description': '\'UTF8\' is deprecated and shouldn\'t be used.'
        }
      ],
      'fitness': {
        'magnitude': 109.0,
        'shortcoming': 3.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/request.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/request.dart`.',
            'file': 'lib/src/request.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/request.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/request.dart` gave the following hint:\n'
                '\n'
                'line: 39 col: 42  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/request.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/request.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/request.dart` gave the following hint:\n'
                '\n'
                'line: 133 col: 26  \n'
                '\'UTF8\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/request.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
        ],
      },
    },
    "lib/src/response.dart": {
      "uri": "package:http/src/response.dart",
      "size": 3431,
      "isFormatted": false,
      "codeProblems": [
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/response.dart',
          'line': 24,
          'col': 8,
          'description': '\'LATIN1\' is deprecated and shouldn\'t be used.'
        },
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/response.dart',
          'line': 83,
          'col': 18,
          'description': '\'LATIN1\' is deprecated and shouldn\'t be used.'
        }
      ],
      'fitness': {
        'magnitude': 62.0,
        'shortcoming': 3.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/response.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/response.dart`.',
            'file': 'lib/src/response.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/response.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/response.dart` gave the following hint:\n'
                '\n'
                'line: 24 col: 8  \n'
                '\'LATIN1\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/response.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/response.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/response.dart` gave the following hint:\n'
                '\n'
                'line: 83 col: 18  \n'
                '\'LATIN1\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/response.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
        ],
      },
    },
    "lib/src/streamed_request.dart": {
      "uri": "package:http/src/streamed_request.dart",
      "size": 1650,
      "isFormatted": false,
      "codeProblems": [],
      'fitness': {
        'magnitude': 28.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/streamed_request.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/streamed_request.dart`.',
            'file': 'lib/src/streamed_request.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/src/streamed_response.dart": {
      "uri": "package:http/src/streamed_response.dart",
      "size": 1326,
      "isFormatted": false,
      "codeProblems": [],
      'fitness': {
        'magnitude': 25.0,
        'shortcoming': 1.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/streamed_response.dart`.',
            'description':
                'Run `dartfmt` to format `lib/src/streamed_response.dart`.',
            'file': 'lib/src/streamed_response.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
        ],
      },
    },
    "lib/src/utils.dart": {
      "uri": "package:http/src/utils.dart",
      "size": 4843,
      "isFormatted": false,
      "codeProblems": [
        {
          'severity': 'INFO',
          'errorType': 'HINT',
          'errorCode': 'DEPRECATED_MEMBER_USE',
          'file': 'lib/src/utils.dart',
          'line': 43,
          'col': 66,
          'description': '\'LATIN1\' is deprecated and shouldn\'t be used.'
        }
      ],
      'fitness': {
        'magnitude': 96.0,
        'shortcoming': 2.0,
        'suggestions': [
          {
            'level': 'hint',
            'title': 'Format `lib/src/utils.dart`.',
            'description': 'Run `dartfmt` to format `lib/src/utils.dart`.',
            'file': 'lib/src/utils.dart',
            'penalty': {'amount': 1, 'fraction': 0},
          },
          {
            'level': 'hint',
            'title': 'Fix `lib/src/utils.dart`.',
            'description':
                'Strong-mode analysis of `lib/src/utils.dart` gave the following hint:\n'
                '\n'
                'line: 43 col: 66  \n'
                '\'LATIN1\' is deprecated and shouldn\'t be used.\n'
                '',
            'file': 'lib/src/utils.dart',
            'penalty': {'amount': 1, 'fraction': 0}
          },
        ],
      },
    },
    "lib/testing.dart": {
      "uri": "package:http/testing.dart",
      "size": 966,
      "isFormatted": true,
      "codeProblems": [],
      "directLibs": ["package:http/src/mock_client.dart"],
      "transitiveLibs": [
        "dart:async",
        "dart:collection",
        "dart:convert",
        "dart:io",
        "dart:math",
        "dart:typed_data",
        "package:async/async.dart",
        "package:async/src/async_cache.dart",
        "package:async/src/async_memoizer.dart",
        "package:async/src/byte_collector.dart",
        "package:async/src/cancelable_operation.dart",
        "package:async/src/delegate/event_sink.dart",
        "package:async/src/delegate/future.dart",
        "package:async/src/delegate/sink.dart",
        "package:async/src/delegate/stream.dart",
        "package:async/src/delegate/stream_consumer.dart",
        "package:async/src/delegate/stream_sink.dart",
        "package:async/src/delegate/stream_subscription.dart",
        "package:async/src/future_group.dart",
        "package:async/src/lazy_stream.dart",
        "package:async/src/null_stream_sink.dart",
        "package:async/src/restartable_timer.dart",
        "package:async/src/result.dart",
        "package:async/src/result/capture_sink.dart",
        "package:async/src/result/capture_transformer.dart",
        "package:async/src/result/error.dart",
        "package:async/src/result/future.dart",
        "package:async/src/result/release_sink.dart",
        "package:async/src/result/release_transformer.dart",
        "package:async/src/result/value.dart",
        "package:async/src/single_subscription_transformer.dart",
        "package:async/src/stream_completer.dart",
        "package:async/src/stream_group.dart",
        "package:async/src/stream_queue.dart",
        "package:async/src/stream_sink_completer.dart",
        "package:async/src/stream_sink_transformer.dart",
        "package:async/src/stream_sink_transformer/handler_transformer.dart",
        "package:async/src/stream_sink_transformer/stream_transformer_wrapper.dart",
        "package:async/src/stream_sink_transformer/typed.dart",
        "package:async/src/stream_splitter.dart",
        "package:async/src/stream_subscription_transformer.dart",
        "package:async/src/stream_zip.dart",
        "package:async/src/subscription_stream.dart",
        "package:async/src/typed/future.dart",
        "package:async/src/typed/stream.dart",
        "package:async/src/typed/stream_subscription.dart",
        "package:async/src/typed_stream_transformer.dart",
        "package:async/src/utils.dart",
        "package:charcode/ascii.dart",
        "package:charcode/charcode.dart",
        "package:charcode/html_entity.dart",
        "package:collection/collection.dart",
        "package:collection/src/algorithms.dart",
        "package:collection/src/canonicalized_map.dart",
        "package:collection/src/combined_wrappers/combined_iterable.dart",
        "package:collection/src/combined_wrappers/combined_list.dart",
        "package:collection/src/combined_wrappers/combined_map.dart",
        "package:collection/src/comparators.dart",
        "package:collection/src/empty_unmodifiable_set.dart",
        "package:collection/src/equality.dart",
        "package:collection/src/equality_map.dart",
        "package:collection/src/equality_set.dart",
        "package:collection/src/functions.dart",
        "package:collection/src/iterable_zip.dart",
        "package:collection/src/priority_queue.dart",
        "package:collection/src/queue_list.dart",
        "package:collection/src/typed_wrappers.dart",
        "package:collection/src/union_set.dart",
        "package:collection/src/union_set_controller.dart",
        "package:collection/src/unmodifiable_wrappers.dart",
        "package:collection/src/utils.dart",
        "package:collection/src/wrappers.dart",
        "package:http/src/base_client.dart",
        "package:http/src/base_request.dart",
        "package:http/src/base_response.dart",
        "package:http/src/byte_stream.dart",
        "package:http/src/client.dart",
        "package:http/src/exception.dart",
        "package:http/src/io_client.dart",
        "package:http/src/mock_client.dart",
        "package:http/src/request.dart",
        "package:http/src/response.dart",
        "package:http/src/streamed_response.dart",
        "package:http/src/utils.dart",
        "package:http_parser/http_parser.dart",
        "package:http_parser/src/authentication_challenge.dart",
        "package:http_parser/src/case_insensitive_map.dart",
        "package:http_parser/src/chunked_coding.dart",
        "package:http_parser/src/chunked_coding/decoder.dart",
        "package:http_parser/src/chunked_coding/encoder.dart",
        "package:http_parser/src/http_date.dart",
        "package:http_parser/src/media_type.dart",
        "package:http_parser/src/scan.dart",
        "package:http_parser/src/utils.dart",
        "package:path/path.dart",
        "package:path/src/characters.dart",
        "package:path/src/context.dart",
        "package:path/src/internal_style.dart",
        "package:path/src/parsed_path.dart",
        "package:path/src/path_exception.dart",
        "package:path/src/style.dart",
        "package:path/src/style/posix.dart",
        "package:path/src/style/url.dart",
        "package:path/src/style/windows.dart",
        "package:path/src/utils.dart",
        "package:source_span/source_span.dart",
        "package:source_span/src/colors.dart",
        "package:source_span/src/file.dart",
        "package:source_span/src/location.dart",
        "package:source_span/src/location_mixin.dart",
        "package:source_span/src/span.dart",
        "package:source_span/src/span_exception.dart",
        "package:source_span/src/span_mixin.dart",
        "package:source_span/src/span_with_context.dart",
        "package:source_span/src/utils.dart",
        "package:string_scanner/src/eager_span_scanner.dart",
        "package:string_scanner/src/exception.dart",
        "package:string_scanner/src/line_scanner.dart",
        "package:string_scanner/src/relative_span_scanner.dart",
        "package:string_scanner/src/span_scanner.dart",
        "package:string_scanner/src/string_scanner.dart",
        "package:string_scanner/src/utils.dart",
        "package:string_scanner/string_scanner.dart",
        "package:typed_data/typed_buffers.dart",
        "package:typed_data/typed_data.dart"
      ],
      'platform': {
        'components': ['io'],
        'uses': {'flutter': 'allowed', 'web': 'forbidden', 'other': 'used'},
      },
      'fitness': {'magnitude': 19.0, 'shortcoming': 0.0},
    },
  },
  'platform': {
    'components': [],
    'uses': {'flutter': 'allowed', 'web': 'allowed', 'other': 'allowed'},
    'reason':
        'No platform restriction found in primary library `package:http/http.dart`.',
  },
  "licenses": [
    {
      "path": "LICENSE",
      "name": "BSD",
      'url': 'https://github.com/dart-lang/http/blob/master/LICENSE',
    },
  ],
  'maintenance': {
    'missingChangelog': false,
    'missingExample': true,
    'missingReadme': false,
    'missingAnalysisOptions': false,
    'oldAnalysisOptions': true,
    'strongModeEnabled': true,
    'isExperimentalVersion': true,
    'isPreReleaseVersion': false,
    'errorCount': 0,
    'warningCount': 0,
    'hintCount': 36,
    'suggestions': [
      {
        'level': 'hint',
        'title': 'Fix analysis and formatting issues.',
        'description': 'Analysis or formatting checks reported 36 hints.\n'
            '\n'
            'Run `dartfmt` to format `lib/browser_client.dart`.\n'
            '\n'
            'Run `dartfmt` to format `lib/http.dart`.\n'
            '\n'
            'Similar analysis of the following files failed:\n'
            '\n'
            '- `lib/src/base_client.dart` (hint)\n'
            '- `lib/src/base_request.dart` (hint)\n'
            '- `lib/src/base_response.dart` (hint)\n'
            '- `lib/src/boundary_characters.dart` (hint)\n'
            '- `lib/src/byte_stream.dart` (hint)\n'
            '- `lib/src/client.dart` (hint)\n'
            '- `lib/src/io_client.dart` (hint)\n'
            '- `lib/src/mock_client.dart` (hint)\n'
            '- `lib/src/multipart_file.dart` (hint)\n'
            '- `lib/src/multipart_request.dart` (hint)\n'
            '- `lib/src/request.dart` (hint)\n'
            '- `lib/src/response.dart` (hint)\n'
            '- `lib/src/streamed_request.dart` (hint)\n'
            '- `lib/src/streamed_response.dart` (hint)\n'
            '- `lib/src/utils.dart` (hint)\n'
            '',
        'penalty': {'amount': 36, 'fraction': 0}
      },
      {
        'level': 'hint',
        'title': 'The description is too short.',
        'description':
            'Add more detail about the package, what it does and what is its target use case. Try to write at least 60 characters.',
        'penalty': {'amount': 20, 'fraction': 0}
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
            'Create a short demo in the `example/` directory to show how to use this package. Common file name patterns include: `main.dart`, `example.dart` or you could also use `http.dart`.',
        'penalty': {'amount': 5, 'fraction': 0}
      },
      {
        'level': 'hint',
        'title': 'Use `analysis_options.yaml`.',
        'description':
            'Rename old `.analysis_options` file to `analysis_options.yaml`.'
      },
    ],
  },
  'fitness': {'magnitude': 1273.0, 'shortcoming': 36.0},
};
