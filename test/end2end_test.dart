import 'dart:convert';
import 'dart:io';

import 'package:pana/pana.dart';
import 'package:test/test.dart';

import 'end2end/pub_server_data.dart' as pub_server_data;

void main() {
  void expectGoldenSummary(Summary summary, Map data) {
    // round-trip the content to get a pure JSON output
    var actualMap = JSON.decode(JSON.encode(summary));

    expect(actualMap, data);
  }

  group('PackageAnalyzer', () {
    Directory tempDir;
    String pubCacheDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('pana-test');
      pubCacheDir = await tempDir.resolveSymbolicLinks();
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    test('pub_server 0.1.1+3', () async {
      var analyzer = new PackageAnalyzer(pubCacheDir: pubCacheDir);
      var summary =
          await analyzer.inspectPackage('pub_server', version: '0.1.1+3');
      expectGoldenSummary(summary, pub_server_data.data);
    }, timeout: const Timeout.factor(2));
  });
}
