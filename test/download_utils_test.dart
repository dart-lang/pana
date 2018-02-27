// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:pana/src/download_utils.dart';

void main() {
  void testGitHubUrls(String prefix) {
    test('user root', () {
      expect(getRepositoryUrl('$prefix/dart-lang', 'README.md'), null);
      expect(getRepositoryUrl('$prefix/dart-lang/', 'README.md'), null);
    });

    test('project root', () {
      expect(getRepositoryUrl('$prefix/dart-lang/angular', 'README.md'),
          '$prefix/dart-lang/angular/blob/master/README.md');
      expect(getRepositoryUrl('$prefix/dart-lang/angular/', 'README.md'),
          '$prefix/dart-lang/angular/blob/master/README.md');
    });

    test('project subdir', () {
      expect(
          getRepositoryUrl(
              '$prefix/dart-lang/angular/tree/master/angular', 'README.md'),
          '$prefix/dart-lang/angular/blob/master/angular/README.md');
      expect(
          getRepositoryUrl(
              '$prefix/dart-lang/angular/tree/master/angular/', 'README.md'),
          '$prefix/dart-lang/angular/blob/master/angular/README.md');
    });

    test('image links in root', () {
      expect(getRepositoryUrl('$prefix/dart-lang/angular', 'logo.png'),
          '$prefix/dart-lang/angular/raw/master/logo.png');
      expect(getRepositoryUrl('$prefix/dart-lang/angular/', 'logo.png'),
          '$prefix/dart-lang/angular/raw/master/logo.png');
    });

    test('image links in project subdir', () {
      expect(
          getRepositoryUrl(
              '$prefix/dart-lang/angular/tree/master/angular', 'logo.png'),
          '$prefix/dart-lang/angular/raw/master/angular/logo.png');
      expect(
          getRepositoryUrl(
              '$prefix/dart-lang/angular/tree/master/angular/', 'logo.png'),
          '$prefix/dart-lang/angular/raw/master/angular/logo.png');
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
      expect(getRepositoryUrl('http://github.com/user/project/', 'README.md'),
          'https://github.com/user/project/blob/master/README.md');
      expect(
          getRepositoryUrl('https://www.github.com/user/project/', 'README.md'),
          'https://github.com/user/project/blob/master/README.md');
    });
  });
}
