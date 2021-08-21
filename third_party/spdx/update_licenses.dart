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
  var licenseMap = <String, String>{};

  final textDirectory =
      Directory('third_party/spdx/licenses/license-list-data-master/text');
  final spdxDirectory =
      Directory('third_party/spdx/licenses/license-list-data-master');

  for (var entity in textDirectory.listSync()) {
    final file = File(entity.path);
    final name = entity.uri.pathSegments.last.split('.txt').first;
    final content = file.readAsStringSync();

    /// Ignore the deprecated licenses as the [SPDX guidelines][1]
    /// suggests that they should not be used.
    ///
    /// [1]: https://github.com/spdx/license-list-data/blob/master/accessingLicenses.md#deprecated-licenses
    if (name.startsWith('deprecated_')) {
      continue;
    }

    // Check for licenses having same text.
    if (checkDuplicatePresent(name, licenseMap, content)) {
      continue;
    } else {
      licenseMap[name] = content;
    }
  }

  await spdxDirectory.delete(recursive: true);
  final basePath = 'third_party/spdx/licenses/';

  licenseMap.forEach((key, value) async {
    final path = basePath + key + '.txt';
    final file = File(path);
    await file.create();
    file.writeAsStringSync(value);
  });
}

/// This routine tries to find exactly licenses having same text and stores them in a normalized license file.
///
/// For example as `AGPL-1.0-only` and `AGPL-1.0-or-later` have same text
/// we store a single license called `AGPL-1.0` instead of two similar license
/// text.
bool checkDuplicatePresent(
    String name, Map<String, String> map, String content) {
  name = name.replaceAll(similarReg, '');

  if (map.containsKey(name)) {
    if (content == map[name]) {
      return true;
    }
    return false;
  }

  if (map.containsKey(name + '-only')) {
    checkIfSameContent(map, content, name + '-only');
    return true;
  }

  if (map.containsKey(name + '-or-later')) {
    checkIfSameContent(map, content, name + '-or-later');
    return true;
  }

  if (map.containsKey(name + '-rfn')) {
    checkIfSameContent(map, content, name + '-rfn');
    return true;
  }

  if (map.containsKey(name + '-no-rfn')) {
    checkIfSameContent(map, content, name + '-no-rfn');
    return true;
  }

  if (map.containsKey(name + '-no-invariants-only')) {
    checkIfSameContent(map, content, name + '-no-invariants-only');
    return true;
  }

  if (map.containsKey(name + '-no-invariants-or-later')) {
    checkIfSameContent(map, content, name + '-no-invariants-or-later');
    return true;
  }
  return false;
}

void checkIfSameContent(Map<String, String> map, String content, String name) {
  if (map[name] == content) {
    map.remove(name);
    map[name.replaceAll(similarReg, '')] = content;
  }
}

final similarReg = RegExp(
    r'(-only|-or-later|-rfn|-no-rfn|-no-invariants-only|-no-invariants-or-later)',
    caseSensitive: false);
