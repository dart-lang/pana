// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
    });
    final suggestion = await analyzeMarkdownFile(file);
    expect(suggestion, isNull);
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
    });
    final suggestion = await analyzeMarkdownFile(file);
    expect(suggestion.toJson(), {
      'code': 'markdown.content',
      'level': 'hint',
      'title': 'Update `bad_images.md`.',
      'description':
          '2 image links are insecure (e.g. `http://example.com/logo.png`), use `https` URLs instead.',
      'file': p.normalize('test/markdown_content/bad_images.md'),
      'score': 4.0,
    });
  });
}
