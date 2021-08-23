import 'dart:convert';
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
  final jsonDirectory = Directory(
      'third_party/spdx/licenses/license-list-data-master/json/details/');
  final spdxDirectory =
      Directory('third_party/spdx/licenses/license-list-data-master');
  final entities = jsonDirectory.listSync();

  var contentList = <String>[];
  var namesList = <String>[];
  var retain = <bool>[];
  for (var entity in entities) {
    final file = File(entity.path);
    final jsonData = json.decode(file.readAsStringSync());
    final content = jsonData['licenseText'] as String;
    final name = jsonData['licenseId'] as String;

    /// Ignore the deprecated licenses as the [SPDX guidelines][1]
    /// suggests that they should not be used.
    ///
    /// [1]: https://github.com/spdx/license-list-data/blob/master/accessingLicenses.md#deprecated-licenses
    if (jsonData['isDeprecatedLicenseId'] as bool) {
      continue;
    }

    contentList.add(content);
    namesList.add(name);
    retain.add(true);
  }

  removeDuplicates(contentList, namesList, retain);
  await spdxDirectory.delete(recursive: true);
  final basePath = 'third_party/spdx/licenses/';

  for (var i = 0; i < contentList.length; i++) {
    if (retain[i]) {
      final path = basePath + namesList[i] + '.txt';
      final file = File(path);
      await file.create();
      file.writeAsStringSync(contentList[i]);
    }
  }
}

/// This routine tries to find licenses having same text and retains only file among the duplicates with normalized name.
///
/// For example as `AGPL-1.0-only` and `AGPL-1.0-or-later` have same text
/// we store a single license called `AGPL-1.0` instead of two similar license
/// text.
void removeDuplicates(
    List<String> contentList, List<String> namesList, List<bool> retain) {
  var len = contentList.length;
  for (var i = 0; i < len; i++) {
    if (retain[i]) {
      var isDuplicatePresent = false;

      for (var j = i + 1; j < len; j++) {
        if (retain[j]) {
          if (contentList[i] == contentList[j]) {
            retain[j] = false;
            isDuplicatePresent = true;
          }
        }
      }

      if (isDuplicatePresent) {
        namesList[i] = namesList[i].replaceAll(similarReg, '');
      }
    }
  }
}

final similarReg = RegExp(
    r'(-only|-or-later|-rfn|-no-rfn|-no-invariants-only|-no-invariants-or-later|-no-copyleft-exception)',
    caseSensitive: false);
