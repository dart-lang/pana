// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:collection/collection.dart';
import 'package:pana/src/api_analysis/common.dart';
import 'package:pana/src/api_analysis/shapes.dart';
import 'package:pana/src/api_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'common.dart';

Future<void> main() async {
  final yamlDir = Directory(path.join(
    path.current,
    'test',
    'api_analysis',
    'testdata',
    'summary',
  ));
  await for (final file in yamlDir.list()) {
    final doc = loadYaml(await (file as File).readAsString());
    test(doc['name'], () async {
      final packagePath = path.canonicalize(path.join('__test_package'));

      final provider = setupBasicPackage(
        packagePath: packagePath,
        packageName: 'test.package',
        packageVersion: '1.0.0',
      );

      // Place every file in memory at the right 'path'.
      for (final node in doc['package']) {
        final filePath =
            path.canonicalize(path.join(packagePath, node['path'] as String));
        provider.setOverlay(
          filePath,
          content: node['content'] as String,
          modificationStamp: 0,
        );
      }

      // Produce JSON summary.
      final session = AnalysisContextCollection(
        includedPaths: [packagePath],
        resourceProvider: provider,
      ).contextFor(packagePath).currentSession;
      final packageAnalysisContext = PackageAnalysisContext(
        session: session,
        packagePath: packagePath,
        warningSink: stderr.nonBlocking,
      );

      final packageShape = await summarizePackage(
        context: packageAnalysisContext,
        packagePath: packagePath,
        normalize: true,
      );

      final packageJson = packageShape.toJson();

      // Compare the summary to what was expected in the yaml doc.
      expect(indentedEncoder.convert(packageJson), equals(doc['summary']));

      // Test the [PackageShape.fromJson] method.
      expect(
        const DeepCollectionEquality().equals(
          PackageShape.fromJson(packageJson).toJson(),
          packageJson,
        ),
        isTrue,
      );
    });
  }
}
