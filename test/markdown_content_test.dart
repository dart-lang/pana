// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pana/src/markdown_content.dart';

void main() {
  test('example.md', () async {
    final file = File('test/markdown_content/example.md');
    final content = await scanMarkdownFileContent(file);
    expect(content.toJson(), {
      'images': ['https://example.com/path.jpg', 'img/path.jpg'],
      'links': ['mailto:hello@example.com'],
      'isMalformedUtf8': false,
      'nonAsciiRatio': 0.0,
    });
  });

  test('bad_images.md', () async {
    final file = File('test/markdown_content/bad_images.md');
    final content = await scanMarkdownFileContent(file);
    expect(content.toJson(), {
      'images': [
        'https::::img',
        'http://example.com/logo.png',
        'gopher://example.com/logo.png',
      ],
      'links': [],
      'isMalformedUtf8': false,
      'nonAsciiRatio': 0.0,
    });
  });

  group('Malformed content', () {
    final time = DateTime.now().millisecondsSinceEpoch;
    final file =
        File(p.join(Directory.systemTemp.path, 'pana-test-malformed-$time.md'));

    tearDownAll(() async {
      await file.delete();
    });

    test('continuation byte', () async {
      await file.writeAsBytes(<int>[
        ...utf8.encode('# Malformed UTF-8\n\n'),
        0x80,
      ]);
      final content = await scanMarkdownFileContent(file);
      expect(content.toJson(), {
        'images': [],
        'links': [],
        'isMalformedUtf8': true,
        'nonAsciiRatio': greaterThan(0.01),
      });
    });

    test('boundary condition', () async {
      await file.writeAsBytes(<int>[
        ...utf8.encode('# Malformed UTF-8\n\n'),
        0xD7,
        0xFF,
      ]);
      final content = await scanMarkdownFileContent(file);
      expect(content.toJson(), {
        'images': [],
        'links': [],
        'isMalformedUtf8': true,
        'nonAsciiRatio': greaterThan(0.01),
      });
    });
  });
}
