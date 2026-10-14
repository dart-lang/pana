// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.linkingEnabled) {
      // In JIT mode (`dart run`, `dart test`), `Isolate.resolvePackageUri`
      // resolves `package:pana/...` directly from the package directory.
      return;
    }

    final licensesDirUri = input.packageRoot.resolve(
      'lib/src/third_party/spdx/licenses/',
    );
    final licensesDir = Directory.fromUri(licensesDirUri);
    final files =
        licensesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.txt'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final licenseTexts = <String, String>{};
    for (final file in files) {
      final id = file.uri.pathSegments.last.split('.txt').first;
      licenseTexts[id] = file.readAsStringSync().replaceAll('\r\n', '\n');
    }

    output.dependencies.addAll(files.map((f) => f.uri));

    final compressed = zlib.encode(utf8.encode(json.encode(licenseTexts)));

    final cFile = File.fromUri(
      input.outputDirectoryShared.resolve('pana_spdx_corpus.c'),
    );
    final sb = StringBuffer()
      ..writeln('#include <stdint.h>')
      ..writeln('#if defined(_WIN32)')
      ..writeln('#define EXPORT __declspec(dllexport)')
      ..writeln('#else')
      ..writeln('#define EXPORT __attribute__((visibility("default")))')
      ..writeln('#endif')
      ..writeln('EXPORT const uint8_t pana_spdx_corpus[] = {');
    for (var i = 0; i < compressed.length; i += 16) {
      final end = i + 16 < compressed.length ? i + 16 : compressed.length;
      sb.writeln('  ${compressed.sublist(i, end).join(', ')},');
    }
    sb
      ..writeln('};')
      ..writeln(
        'EXPORT const uint64_t pana_spdx_corpus_len = ${compressed.length}ULL;',
      );
    final cSource = sb.toString();
    if (!cFile.existsSync() || cFile.readAsStringSync() != cSource) {
      await cFile.writeAsString(cSource);
    }

    final cbuilder = CBuilder.library(
      name: 'pana_spdx_corpus',
      assetName: 'src/license_detection/license_detector.dart',
      sources: [cFile.path],
    );
    await cbuilder.run(input: input, output: output);
    // `cFile` is an intermediate artifact generated during the build; the
    // actual input dependencies are the `.txt` license files added above.
    (output.json['dependencies'] as List<Object?>?)?.remove(
      cFile.uri.toFilePath(),
    );
  });
}
