import 'dart:io';

import 'package:pana/pana.dart';
import 'package:test/test.dart';

void main() {
  void expectGoldenSummary(Summary summary) {
    Map actualMap = summary.toJson();
    actualMap['sdkVersion'] = '[MASKED]';
    String actual = prettyJson(actualMap);

    String goldenPath =
        'test/end2end/${summary.packageName}-${summary.packageVersion}.json';
    String golden = new File(goldenPath).readAsStringSync();

    expect(actual.split('\n'), golden.split('\n'));
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
      expectGoldenSummary(summary);
    }, timeout: const Timeout.factor(2));
  });
}
