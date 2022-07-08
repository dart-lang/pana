import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:pana/src/package_analysis/common.dart';
import 'package:pana/src/package_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

Future<void> main() async {
  final yamlDir = Directory(
      path.join(path.current, 'test', 'package_analysis', 'testdata'));
  final indentedEncoder = const JsonEncoder.withIndent('  ');
  final configTemplate = json.encode({
    'configVersion': 2,
    'packages': [
      {
        'name': 'test_package',
        'rootUri': '../',
        'packageUri': 'lib/',
        'languageVersion': '2.12'
      }
    ],
    'generated': '2022-01-01T00:00:00.000000Z',
    'generator': 'pub',
    'generatorVersion': '2.17.3'
  });
  const pubspecTemplate = 'name: test_package\nversion: 1.0.0';

  for (final file in await yamlDir.list().toList()) {
    final doc = loadYaml(await (file as File).readAsString());
    test(doc['name'], () async {
      final physicalProvider = PhysicalResourceProvider();
      final provider = OverlayResourceProvider(physicalProvider);

      // root package folder
      final packageLocation = path.canonicalize(path.join('test_package'));

      // necessary for the analyzer to be able to set proper library identifiers
      // and package metadata
      provider.setOverlay(
          path.join(packageLocation, '.dart_tool', 'package_config.json'),
          content: configTemplate,
          modificationStamp: 0);
      provider.setOverlay(path.join(packageLocation, 'pubspec.yaml'),
          content: pubspecTemplate, modificationStamp: 0);

      // place every file in memory at the right 'path'
      for (final node in doc['package']) {
        final filePath = path
            .canonicalize(path.join('test_package', node['path'] as String));
        provider.setOverlay(filePath,
            content: node['content'] as String, modificationStamp: 0);
      }

      // produce json summary
      final session = AnalysisContextCollection(
        includedPaths: [packageLocation],
        resourceProvider: provider,
      ).contextFor(packageLocation).currentSession;

      final packageShape = await summarizePackage(
        _PackageAnalysisSession(session),
        packageLocation,
      );

      final packageJson = packageShape.toJson();

      // compare the summary to what was expected in the yaml doc
      expect(indentedEncoder.convert(packageJson), equals(doc['summary']));
    });
  }
}

class _PackageAnalysisSession extends PackageAnalysisSession {
  @override
  late final AnalysisSession analysisSession;

  _PackageAnalysisSession(AnalysisSession session) {
    analysisSession = session;
  }

  @override
  void warning(String message) {
    stderr.writeln(message);
  }
}
