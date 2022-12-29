// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final a = await _read(args[0]);
  final b = await _read(args[1]);

  final changes = <String, List<String>>{};
  final keys = a.keys.toSet().intersection(b.keys.toSet());
  for (final key in keys) {
    final diff = a[key]!.diff(b[key]!);
    for (final d in diff) {
      changes.putIfAbsent(d, () => []).add(key);
    }
  }
  final entries = changes.entries.toList()
    ..sort((a, b) => -a.value.length.compareTo(b.value.length));
  for (final entry in entries) {
    print(
        '${entry.value.length.toString().padLeft(6)} ${entry.key.padLeft(30)}: ${entry.value.take(5).join(', ')}');
  }
}

class LicenseResult {
  final List<String> spdxIds;

  LicenseResult({required this.spdxIds});
  factory LicenseResult.fromJson(Map<String, dynamic> input) {
    return LicenseResult(
        spdxIds:
            (input['spdxIds'] as List?)?.cast<String>() ?? const <String>[]);
  }

  List<String> diff(LicenseResult other) {
    return <String>[
      ...spdxIds.where((id) => !other.spdxIds.contains(id)).map((e) => '-$e'),
      ...other.spdxIds.where((id) => !spdxIds.contains(id)).map((e) => '+$e'),
    ];
  }
}

Future<Map<String, LicenseResult>> _read(String inputFilePath) async {
  final content = await File(inputFilePath).readAsString();
  final data = json.decode(content) as Map<String, dynamic>;
  return data.map((key, value) =>
      MapEntry(key, LicenseResult.fromJson(value as Map<String, dynamic>)));
}
