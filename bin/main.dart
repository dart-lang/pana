// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pkg_clean/pkg_clean.dart';

String _pretty(obj) => const JsonEncoder.withIndent(' ').convert(obj);

main(List<String> arguments) async {
  var tempDir = Directory.systemTemp.createTempSync(
      'pkg_clean.${new DateTime.now().millisecondsSinceEpoch}.');

  try {
    var pkgDir = await downloadPkg(tempDir.path, arguments.single);

    var summary = await pkgSummary(pkgDir);

    print(arguments.single);
    print(_pretty(summary));
  } finally {
    await tempDir.delete(recursive: true);
  }
}
