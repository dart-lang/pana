// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/repository/repository_url.dart';
import 'package:test/test.dart';

void main() {
  void testGitHubUrls(String prefix) {
    test('user root fails', () {
      expect(RepositoryUrl.tryParse('$prefix/dart-lang'), isNull);
      expect(RepositoryUrl.tryParse('$prefix/dart-lang/'), isNull);
    });

    test('project root', () {
      expect(
          RepositoryUrl.parse('$prefix/dart-lang/angular')
              .resolve('README.md')
              .toUrl(),
          '$prefix/dart-lang/angular/blob/master/README.md');
      expect(
          RepositoryUrl.parse('$prefix/dart-lang/angular/')
              .resolve('README.md')
              .toUrl(),
          '$prefix/dart-lang/angular/blob/master/README.md');
    });

    test('project subdir', () {
      expect(
          RepositoryUrl.parse('$prefix/dart-lang/angular/tree/master/angular')
              .resolve('README.md')
              .toUrl(),
          '$prefix/dart-lang/angular/blob/master/angular/README.md');
      expect(
          RepositoryUrl.parse('$prefix/dart-lang/angular/tree/master/angular/')
              .resolve('README.md')
              .toUrl(),
          '$prefix/dart-lang/angular/blob/master/angular/README.md');
    });

    test('image links in root', () {
      expect(
          RepositoryUrl.parse('$prefix/dart-lang/angular')
              .resolve('logo.png')
              .toUrl(),
          '$prefix/dart-lang/angular/raw/master/logo.png');
      expect(
          RepositoryUrl.parse('$prefix/dart-lang/angular/')
              .resolve('logo.png')
              .toUrl(),
          '$prefix/dart-lang/angular/raw/master/logo.png');
    });

    test('image links in specific branch', () {
      expect(
        RepositoryUrl.parse('$prefix/dart-lang/angular')
            .resolve(
              'logo.png',
              branch: 'main',
            )
            .toUrl(),
        '$prefix/dart-lang/angular/raw/main/logo.png',
      );
    });

    test('image links in project subdir', () {
      expect(
          RepositoryUrl.parse('$prefix/dart-lang/angular/tree/master/angular')
              .resolve('logo.png')
              .toUrl(),
          '$prefix/dart-lang/angular/raw/master/angular/logo.png');
      expect(
          RepositoryUrl.parse('$prefix/dart-lang/angular/tree/master/angular/')
              .resolve('logo.png')
              .toUrl(),
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
      expect(
          RepositoryUrl.parse('http://github.com/user/project/')
              .resolve('README.md')
              .toUrl(),
          'https://github.com/user/project/blob/master/README.md');
      expect(
          RepositoryUrl.parse('https://www.github.com/user/project/')
              .resolve('README.md')
              .toUrl(),
          'https://github.com/user/project/blob/master/README.md');
    });

    test('.git URL', () {
      expect(
          RepositoryUrl.parse(
                  'https://github.com/daniel-maxhari/dynamic_text_highlighting.git')
              .resolve('LICENSE')
              .toUrl(),
          'https://github.com/daniel-maxhari/dynamic_text_highlighting/blob/master/LICENSE');

      expect(
          RepositoryUrl.parse(
                  'https://github.com/daniel-maxhari/dynamic_text_highlighting.git/blob/master/subdir')
              .resolve('LICENSE')
              .toUrl(),
          'https://github.com/daniel-maxhari/dynamic_text_highlighting/blob/master/subdir/LICENSE');
    });
  });
}
