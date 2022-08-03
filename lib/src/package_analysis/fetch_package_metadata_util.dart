import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';
import 'package:retry/retry.dart';

// all packages used by package:test transitively:
const smallSubset1 = [
  'test',
  'test_core',
  'test_api',
  'matcher',
  'stack_trace',
  'path',
  'term_glyph',
  'string_scanner',
  'source_span',
  'collection',
  'stream_channel',
  'async',
  'meta',
  'boolean_selector',
  'yaml',
  'vm_service',
  'source_maps',
  'source_map_stack_trace',
  'pool',
  'package_config',
  'io',
  'glob',
  'file',
  'frontend_server_client',
  'coverage',
  'logging',
  'args',
  'analyzer',
  'watcher',
  'pub_semver',
  'crypto',
  'typed_data',
  'convert',
  '_fe_analyzer_shared',
  'webkit_inspection_protocol',
  'web_socket_channel',
  'shelf_web_socket',
  'shelf',
  'http_parser',
  'shelf_static',
  'mime',
  'shelf_packages_handler',
  'node_preamble',
  'js',
  'http_multi_server'
];
// all packages published by dart.dev or tools.dart.dev, excluding the hidden packages _fe_analyzer_shared and http_retry
const smallSubset2 = [
  'mime',
  'yaml',
  'stream_transform',
  'lints',
  'pub_semver',
  'usage',
  'shelf_static',
  'json_rpc_2',
  'shelf_proxy',
  'http_multi_server',
  'graphs',
  'ffigen',
  'web_socket_channel',
  'shelf',
  'string_scanner',
  'watcher',
  'markdown',
  'boolean_selector',
  'shelf_web_socket',
  'oauth2',
  'code_builder',
  'dds',
  'pool',
  'cli_util',
  'vm_service',
  'io',
  'stack_trace',
  'package_config',
  'dartdoc',
  'browser_launcher',
  'pubspec_parse',
  'yaml_edit',
  'linter',
  'build_runner',
  'html',
  'analyzer',
  'clock',
  'timing',
  'dart_style',
  'glob',
  'stream_channel',
  'csslib',
  'term_glyph',
  'sse',
  'analyzer_plugin',
  'build_daemon',
  'build_web_compilers',
  'source_span',
  'coverage',
  'native_stack_traces',
  'benchmark_harness',
  'source_map_stack_trace',
  'build_config',
  'build_test',
  'dwds',
  'vm_snapshot_analysis',
  'test_api',
  'source_gen',
  'webdev',
  'scratch_space',
  'frontend_server_client',
  'build_resolvers',
  'pana',
  'shelf_packages_handler',
  'test_process',
  'shelf_test_handler',
  'bazel_worker',
  'build_modules',
  'test_descriptor',
  'test_core',
  'dds_service_extensions',
  'build_runner_core',
  'build_vm_compilers',
  'analysis_server_client',
  'source_maps',
  'test_reflective_loader',
  'http',
  'path',
  'crypto',
  'logging',
  'args',
  'js',
  'characters',
  'ffi',
  'http_parser',
  'convert',
  'build',
  'collection',
  'async',
  'mockito',
  'test',
  'grpc',
  'fake_async',
  'typed_data',
  'matcher',
  'fixnum',
  'intl',
  'meta',
  'os_detect',
  'http2',
  'intl_translation'
];

// https://pub.dev/api/package-names
const allPackages = [];

Future<void> main() async {
  final c = http.Client();

  var file = File('package-metadata-sorted.json');

  var counter = 0;

  final length = allPackages.length;

  final result = <dynamic>[];

  try {
    final pool = Pool(16);

    await Future.wait(allPackages.map((package) async {
      await pool.withResource(() async {
        try {
          final scoreUrl =
              Uri.parse('https://pub.dev/api/packages/$package/score');
          final scoreDataRaw = await retry(
            () => c.get(scoreUrl),
            retryIf: (e) => e is IOException,
          );

          final scoreData = json.decode(scoreDataRaw.body);

          final versionsUrl =
              Uri.parse('https://pub.dev/api/packages/$package');
          final versionsDataRaw = await retry(
            () => c.get(versionsUrl),
            retryIf: (e) => e is IOException,
          );
          final versionsData = json.decode(versionsDataRaw.body);

          result.add({
            'scoreData': scoreData,
            'metadata': versionsData,
          });

          print('progress: ${(counter++ / length) * 100}');
        } catch (e) {
          // skip this package
          print('warning: failed to get info for package: $package');
        }
      });
    }));
  } finally {
    c.close();
  }

  result.sort((a, b) {
    final A = a['scoreData']['popularityScore'] as double;
    final B = b['scoreData']['popularityScore'] as double;
    return B.compareTo(A);
  });

  await file.writeAsString(json.encode(<String, dynamic>{'packages': result}),
      mode: FileMode.write);
}
