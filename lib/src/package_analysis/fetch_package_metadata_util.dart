import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';
import 'package:retry/retry.dart';

// ( https://pub.dev/api/package-names can also be used)
// all packages used by package:test transitively:
List<String> allPackages = [
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

Future<void> main() async {
  final c = http.Client();

  var file = File('subset-metadata-sorted.json');

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
