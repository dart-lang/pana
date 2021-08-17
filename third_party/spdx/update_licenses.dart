import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

void main() async {
  const downloadUrl =
      'https://github.com/spdx/license-list-data/archive/refs/heads/master.zip';
  final client = http.Client();
  final licenseDirectory = Directory('third_party/spdx/licenses');
  final response = await client.get(Uri.parse(downloadUrl));
  final decoder = ZipDecoder();

  if (response.statusCode != 200) {
    print('Error downloading files');
    print(response.statusCode);
    return;
  }

  await _emptyDirectory(licenseDirectory);
  await writeFiles(decoder.decodeBytes(response.bodyBytes));
  await removeUnnecessaryFiles();
}

Future<void> _emptyDirectory(Directory dir) async {
  final files = dir.listSync();

  for (var f in files) {
    final file = File(f.path);
    await file.delete();
  }
}

Future<void> writeFiles(Archive archive) async {
  for (var f in archive.files) {
    if (f.isFile) {
      final name = f.name;
      final file = File('third_party/spdx/licenses/$name');
      await file.create();
      await file.writeAsBytes(f.content as Uint8List);
    } else {
      await Directory('third_party/spdx/licenses/${f.name}')
          .create(recursive: true);
    }
  }
}

Future<void> removeUnnecessaryFiles() async {
  final textDirectory =
      Directory('third_party/spdx/licenses/license-list-data-master/text');
  final spdxDirectory =
      Directory('third_party/spdx/licenses/license-list-data-master');

  for (var entity in textDirectory.listSync()) {
    final file = File(entity.path);
    final name = entity.uri.pathSegments.last;
    if (name.startsWith('deprecated_')) continue;
    await file.copy('third_party/spdx/licenses/$name');
  }

  await spdxDirectory.delete(recursive: true);
}
