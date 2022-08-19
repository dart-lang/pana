import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:pana/src/package_analysis/common.dart';
import 'package:pana/src/package_analysis/package_analysis.dart';
import 'package:pana/src/package_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'common.dart';

Future<void> main() async {
  final yamlDir = Directory(path.join(
    path.current,
    'test',
    'package_analysis',
    'testdata',
    'summary',
  ));
  await for (final file in yamlDir.list()) {
    final doc = loadYaml(await (file as File).readAsString());
    test(doc['name'], () async {
      final packagePath = path.canonicalize(path.join('test_package'));

      final provider = setupBasicPackage(
        packagePath: packagePath,
        packageName: 'test.package',
        packageVersion: '1.0.0',
      );

      // place every file in memory at the right 'path'
      for (final node in doc['package']) {
        final filePath = path.canonicalize(path.join(
          'test_package',
          node['path'] as String,
        ));
        provider.setOverlay(
          filePath,
          content: node['content'] as String,
          modificationStamp: 0,
        );
      }

      // produce json summary
      final session = AnalysisContextCollection(
        includedPaths: [packagePath],
        resourceProvider: provider,
      ).contextFor(packagePath).currentSession;
      final packageAnalysisContext = PackageAnalysisContextWithStderr(
        session: session,
        packagePath: packagePath,
      );

      final packageShape = await summarizePackage(
        context: packageAnalysisContext,
        packagePath: packagePath,
      );

      final packageJson = packageShape.toJson();

      // compare the summary to what was expected in the yaml doc
      expect(indentedEncoder.convert(packageJson), equals(doc['summary']));
    });
  }
}
