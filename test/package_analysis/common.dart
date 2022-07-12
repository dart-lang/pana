import 'dart:convert';

import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as path;

String getConfigTemplate({
  required String packageName,
  required String packageVersion,
}) =>
    json.encode({
      'configVersion': 2,
      'packages': [
        {
          'name': packageName,
          'rootUri': '../',
          'packageUri': 'lib/',
          'languageVersion': '2.12'
        }
      ],
      'generated': '2022-01-01T00:00:00.000000Z',
      'generator': 'pub',
      'generatorVersion': '2.17.3'
    });

String getPubspecTemplate({
  required String packageName,
  required String packageVersion,
}) =>
    'name: $packageName\nversion: $packageVersion';

OverlayResourceProvider setupBasicPackage({
  required String packagePath,
  required String packageName,
  required String packageVersion,
}) {
  final physicalProvider = PhysicalResourceProvider();
  final provider = OverlayResourceProvider(physicalProvider);

  provider.setOverlay(
    path.join(packagePath, '.dart_tool', 'package_config.json'),
    content: getConfigTemplate(
        packageName: packageName, packageVersion: packageVersion),
    modificationStamp: 0,
  );
  provider.setOverlay(
    path.join(packagePath, 'pubspec.yaml'),
    content: getPubspecTemplate(
        packageName: packageName, packageVersion: packageVersion),
    modificationStamp: 0,
  );

  return provider;
}
