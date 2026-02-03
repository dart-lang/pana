// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pana/pana.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart';

final _pubDevUri = Uri.parse('https://pub.dev/');

class TestEnv {
  final Directory tempDir;
  final HttpServer _httpServer;
  final http.Client _httpClient;
  final ToolEnvironment _toolEnv;

  TestEnv._(this.tempDir, this._httpServer, this._httpClient, this._toolEnv);

  late final _panaCacheDir = Directory(p.join(tempDir.path, 'pana-cache'))
    ..createSync();

  static Future<TestEnv> createTemp({
    DateTime? proxyPublishCutoff,
    String? dartdocVersion,
  }) async {
    final tempPath = Directory.systemTemp
        .createTempSync('pana-test')
        .resolveSymbolicLinksSync();
    final pubCacheDir = p.join(tempPath, 'pub-cache');
    final dartConfigDir = p.join(tempPath, 'config', 'dart');
    final flutterConfigDir = p.join(tempPath, 'config', 'flutter');
    final tempDir = Directory(tempPath);
    Directory(pubCacheDir).createSync();
    Directory(dartConfigDir).createSync(recursive: true);
    Directory(flutterConfigDir).createSync(recursive: true);

    final (httpServer, httpClient) = await _startLocalProxy(
      publishCutoff: proxyPublishCutoff ?? DateTime.now(),
    );

    final toolEnv = await ToolEnvironment.create(
      dartSdkConfig: SdkConfig(configHomePath: dartConfigDir),
      flutterSdkConfig: SdkConfig(configHomePath: flutterConfigDir),
      pubCacheDir: pubCacheDir,
      pubHostedUrl: 'http://localhost:${httpServer.port}',
      dartdocVersion: dartdocVersion ?? 'any',
      useAnalysisIncludes: true,
    );

    return TestEnv._(tempDir, httpServer, httpClient, toolEnv);
  }

  late final analyzer = PackageAnalyzer(_toolEnv);

  InspectOptions inspectOptions({String? dartdocOutputDir}) {
    return InspectOptions(
      pubHostedUrl: 'http://127.0.0.1:${_httpServer.port}',
      panaCacheDir: _panaCacheDir.path,
      dartdocOutputDir: dartdocOutputDir,
    );
  }

  Future<Summary> inspectDir(String packageDir) async {
    return analyzer.inspectDir(packageDir, options: inspectOptions());
  }

  Future<void> close() async {
    _httpClient.close();
    await _httpServer.close(force: true);
    await tempDir.delete(recursive: true);
  }
}

Future<(HttpServer, http.Client)> _startLocalProxy({
  required DateTime publishCutoff,
}) async {
  final client = http.Client();
  final server = await serve(
    (shelf.Request rq) async {
      final pubDevUri = _pubDevUri.replace(path: rq.requestedUri.path);
      final rs = await client.get(pubDevUri);
      final segments = rq.requestedUri.pathSegments;
      if (rs.statusCode == 200 &&
          segments.length == 3 &&
          segments[0] == 'api' &&
          segments[1] == 'packages') {
        final content = json.decode(rs.body) as Map<String, dynamic>;
        final versions = (content['versions'] as List)
            .cast<Map<String, dynamic>>();
        versions.removeWhere((item) {
          final published = DateTime.parse(item['published'] as String);
          return published.isAfter(publishCutoff);
        });
        return shelf.Response.ok(json.encode(content));
      }
      return shelf.Response(
        rs.statusCode,
        body: gzip.encode(rs.bodyBytes),
        headers: {'content-encoding': 'gzip'},
      );
    },
    '127.0.0.1',
    0,
  );
  return (server, client);
}

class PackageDirBuilder {
  final String _rootPath;
  PackageDirBuilder(this._rootPath);

  Future<void> writeFile(String path, String content) async {
    final file = File(p.join(_rootPath, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<void> writePubspec({
    String name = 'pkg',
    Map<String, dynamic>? devDependencies,
  }) async {
    await writeFile(
      'pubspec.yaml',
      json.encode({
        'name': name,
        'publish_to': 'none',
        'environment': {'sdk': '^3.9.0'},
        'dev_dependencies': ?devDependencies,
      }),
    );
  }
}
