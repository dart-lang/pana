// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

import 'package:pana/src/markdown_content.dart';

void main() {
  test('example.md', () async {
    final file = File('test/markdown_content/example.md');
    final content = await scanMarkdownFileContent(file);
    expect(content.toJson(), {
      'parseError': null,
      'images': ['https://example.com/path.jpg', 'img/path.jpg'],
      'links': [],
    });
    final suggestion = await analyzeMarkdownFile(file);
    expect(suggestion, isNull);
  });

  test('bad_images.md', () async {
    final file = File('test/markdown_content/bad_images.md');
    final content = await scanMarkdownFileContent(file);
    expect(content.toJson(), {
      'parseError': null,
      'images': ['https::::img', 'http://example.com/logo.png'],
      'links': [],
    });
    final suggestion = await analyzeMarkdownFile(file);
    expect(suggestion.toJson(), {
      'code': 'markdown.content',
      'level': 'hint',
      'title': 'Update `bad_images.md`.',
      'description':
          '1 image link is insecure (e.g. `http://example.com/logo.png`), use `https` URLs instead.',
      'file': 'test/markdown_content/bad_images.md',
      'score': 2.0,
    });
  });
}
