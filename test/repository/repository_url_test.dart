// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/model.dart';
import 'package:test/test.dart';

void main() {
  void testGitHubUrls(String prefix) {
    test('user root fails', () {
      expect(Repository.tryParseUrl('$prefix/dart-lang'), isNull);
      expect(Repository.tryParseUrl('$prefix/dart-lang/'), isNull);
    });

    test('project in root', () {
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular')
              .resolveUrl('README.md'),
          '$prefix/dart-lang/angular/blob/master/README.md');
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular/')
              .resolveUrl('README.md'),
          '$prefix/dart-lang/angular/blob/master/README.md');
    });

    test('project in subdir', () {
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular/tree/master/angular')
              .resolveUrl('README.md'),
          '$prefix/dart-lang/angular/blob/master/angular/README.md');
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular/tree/master/angular/')
              .resolveUrl('README.md'),
          '$prefix/dart-lang/angular/blob/master/angular/README.md');
    });

    test('image links from root', () {
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular')
              .resolveUrl('logo.png'),
          '$prefix/dart-lang/angular/raw/master/logo.png');
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular/')
              .resolveUrl('logo.png'),
          '$prefix/dart-lang/angular/raw/master/logo.png');
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular/')
              .resolveUrl('dir/logo.png'),
          '$prefix/dart-lang/angular/raw/master/dir/logo.png');
    });

    test('image links in project subdir', () {
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular/tree/master/angular')
              .resolveUrl('logo.png'),
          '$prefix/dart-lang/angular/raw/master/angular/logo.png');
      expect(
          Repository.parseUrl('$prefix/dart-lang/angular/tree/master/angular/')
              .resolveUrl('logo.png'),
          '$prefix/dart-lang/angular/raw/master/angular/logo.png');
    });

    test('file link with anchor', () {
      expect(
        Repository.parseUrl('$prefix/dart-lang/pub-dev')
            .resolveUrl('README.md#title'),
        '$prefix/dart-lang/pub-dev/blob/master/README.md#title',
      );
    });

    test('local link with anchor', () {
      expect(
        Repository.parseUrl('$prefix/dart-lang/pub-dev').resolveUrl('#title'),
        '#title',
      );
    });

    test('bad reference URI', () {
      expect(
        Repository.parseUrl('$prefix/dart-lang/pub-dev')
            .tryResolveUrl('http ://x'),
        isNull,
      );
    });

    test('absolute reference URI', () {
      expect(
        Repository.parseUrl('$prefix/dart-lang/pub-dev')
            .resolveUrl('https://example.com/y'),
        'https://example.com/y',
      );
    });
  }

  group('GitHub URLs', () {
    testGitHubUrls('https://github.com');
  });

  group('GitLab URLs', () {
    testGitHubUrls('https://gitlab.com');
  });

  group('URL replacements', () {
    test('GitHub replacements', () {
      expect(
          Repository.parseUrl('http://github.com/user/project/')
              .resolveUrl('README.md'),
          'https://github.com/user/project/blob/master/README.md');
      expect(
          Repository.parseUrl('https://www.github.com/user/project/')
              .resolveUrl('README.md'),
          'https://github.com/user/project/blob/master/README.md');
    });

    test('.git URL', () {
      expect(
          Repository.parseUrl(
                  'https://github.com/daniel-maxhari/dynamic_text_highlighting.git')
              .resolveUrl('LICENSE'),
          'https://github.com/daniel-maxhari/dynamic_text_highlighting/blob/master/LICENSE');

      expect(
          Repository.parseUrl(
                  'https://github.com/daniel-maxhari/dynamic_text_highlighting.git/blob/master/subdir')
              .resolveUrl('LICENSE'),
          'https://github.com/daniel-maxhari/dynamic_text_highlighting/blob/master/subdir/LICENSE');
    });
  });

  group('parse failures', () {
    test('double colon', () {
      expect(
          Repository.tryParseUrl('https::github.com/dart-lang/pana'), isNull);
    });

    test('spaces in host', () {
      expect(Repository.tryParseUrl('https:/ /github .com/dart-lang/pana'),
          isNull);
    });
  });
}
