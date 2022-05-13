import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

const _spdxPath = 'lib/src/third_party/spdx';
const _targetPath = '$_spdxPath/licenses';

void main() async {
  const downloadUrl =
      'https://github.com/spdx/license-list-data/archive/refs/heads/master.zip';
  final client = http.Client();
  final licenseDirectory = Directory(_targetPath);
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
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
  await dir.create(recursive: true);
}

Future<void> writeFiles(Archive archive) async {
  for (var f in archive.files) {
    if (f.isFile) {
      final name = f.name;
      final file = File('$_targetPath/$name');
      await file.create();
      await file.writeAsBytes(f.content as Uint8List);
    } else {
      await Directory('$_targetPath/${f.name}').create(recursive: true);
    }
  }
}

Future<void> removeUnnecessaryFiles() async {
  final jsonDirectory =
      Directory('$_targetPath/license-list-data-master/json/details/');
  final spdxDirectory = Directory('$_targetPath/license-list-data-master');
  final entities = jsonDirectory.listSync();

  final licenses = <_LicenseData>[];
  for (var entity in entities) {
    final file = File(entity.path);
    final jsonData =
        json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    final text = jsonData['licenseText'] as String;
    final identifier = jsonData['licenseId'] as String;

    /// Ignore the deprecated licenses as the [SPDX guidelines][1]
    /// suggests that they should not be used.
    ///
    /// [1]: https://github.com/spdx/license-list-data/blob/master/accessingLicenses.md#deprecated-licenses
    if (jsonData['isDeprecatedLicenseId'] as bool) {
      continue;
    }
    final isOsiApproved = (jsonData['isOsiApproved'] as bool?) ?? false;
    final isFsfLibre = (jsonData['isFsfLibre'] as bool?) ?? false;
    licenses.add(_LicenseData(
      identifier,
      text,
      isFsfLibre: isFsfLibre,
      isOsiApproved: isOsiApproved,
    ));
  }

  _removeDuplicates(licenses);
  await spdxDirectory.delete(recursive: true);
  final basePath = '$_targetPath/';

  final fsfLibre = <String>{};
  final osiApproved = <String>{};
  for (final license in licenses) {
    if (license.retain) {
      final path = '$basePath${license.identifier}.txt';
      final file = File(path);
      await file.create();
      file.writeAsStringSync(license.text);
      if (license.isFsfLibre) {
        fsfLibre.add(license.identifier);
      }
      if (license.isOsiApproved) {
        osiApproved.add(license.identifier);
      }
    }
  }

  await File('$_spdxPath/licenses.dart').writeAsString([
    '// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file',
    '// for details. All rights reserved. Use of this source code is governed by a',
    '// BSD-style license that can be found in the LICENSE file.',
    '',
    '/// FSF Free/Libre',
    'const fsfLibreLicenses = <String>{',
    ...(fsfLibre.toList()..sort()).map((id) => '  \'$id\','),
    '};',
    '',
    '/// OSI Approved',
    'const osiApprovedLicenses = <String>{',
    ...(osiApproved.toList()..sort()).map((id) => '  \'$id\','),
    '};',
    '',
  ].join('\n'));
}

/// This routine tries to find licenses having same text and retains only file among the duplicates with normalized name.
///
/// For example as `AGPL-1.0-only` and `AGPL-1.0-or-later` have same text
/// we store a single license called `AGPL-1.0` instead of two similar license
/// text.
void _removeDuplicates(List<_LicenseData> licenses) {
  for (var i = 0; i < licenses.length; i++) {
    if (licenses[i].retain) {
      var isDuplicatePresent = false;

      for (var j = i + 1; j < licenses.length; j++) {
        if (licenses[j].retain) {
          if (licenses[i].text == licenses[j].text) {
            licenses[j].retain = false;
            isDuplicatePresent = true;
          }
        }
      }

      if (isDuplicatePresent) {
        licenses[i].identifier =
            licenses[i].identifier.replaceAll(_similarReg, '');
      }
    }
  }
}

final _similarReg = RegExp(
    r'(-only|-or-later|-rfn|-no-rfn|-no-invariants-only|-no-invariants-or-later|-no-copyleft-exception)',
    caseSensitive: false);

class _LicenseData {
  String identifier;
  final String text;
  final bool isFsfLibre;
  final bool isOsiApproved;
  bool retain = true;

  _LicenseData(
    this.identifier,
    this.text, {
    required this.isFsfLibre,
    required this.isOsiApproved,
  });
}
