import 'dart:convert';

import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as path;
import 'package:test_descriptor/test_descriptor.dart';

String _createPackageConfig({
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
          'languageVersion': '2.13'
        }
      ],
      'generated': '2022-01-01T00:00:00.000000Z',
      'generator': 'pub',
      'generatorVersion': '2.17.3'
    });

String _createPubspec({
  required String packageName,
  required String packageVersion,
}) =>
    'name: $packageName\nversion: $packageVersion\n';

OverlayResourceProvider setupBasicPackage({
  required String packagePath,
  required String packageName,
  required String packageVersion,
}) {
  final physicalProvider = PhysicalResourceProvider();
  final provider = OverlayResourceProvider(physicalProvider);

  provider.setOverlay(
    path.join(packagePath, '.dart_tool', 'package_config.json'),
    content: _createPackageConfig(
        packageName: packageName, packageVersion: packageVersion),
    modificationStamp: 0,
  );
  provider.setOverlay(
    path.join(packagePath, 'pubspec.yaml'),
    content: _createPubspec(
        packageName: packageName, packageVersion: packageVersion),
    modificationStamp: 0,
  );

  return provider;
}

/// Create a [FileDescriptor] from a yaml node with `path` and `content` keys.
FileDescriptor descriptorFromYamlNode(package) {
  final packagePath = package['path'] as String;
  final packageContent = package['content'] as String;
  return FileDescriptor(
    path.joinAll(packagePath.split('/')),
    packageContent,
  );
}
