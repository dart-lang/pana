// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/download_utils.dart';
import 'package:test/test.dart';

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

    test('.git URL', () {
      expect(
          getRepositoryUrl(
              'https://github.com/daniel-maxhari/dynamic_text_highlighting.git',
              'LICENSE'),
          'https://github.com/daniel-maxhari/dynamic_text_highlighting/blob/master/LICENSE');

      expect(
          getRepositoryUrl(
              'https://github.com/daniel-maxhari/dynamic_text_highlighting.git/blob/master/subdir',
              'LICENSE'),
          'https://github.com/daniel-maxhari/dynamic_text_highlighting/blob/master/subdir/LICENSE');
    });
  });

  group('UrlChecker', () {
    test('problem: invalid', () async {
      final status = await UrlChecker().checkStatus('htp://pub.dev/');
      expect(status.isInvalid, true);
      expect(status.isInternal, false);
      expect(status.isSecure, false);
      expect(status.exists, false);
      expect(status.getProblemCode(packageIsKnownInternal: false), 'invalid');
      expect(status.getProblemCode(packageIsKnownInternal: true), 'invalid');
    });

    test('problem: internal', () async {
      final status = await UrlChecker().checkStatus('https://pub.dev/');
      expect(status.isInvalid, false);
      expect(status.isInternal, true);
      expect(status.isSecure, true);
      expect(status.exists, true);
      expect(status.getProblemCode(packageIsKnownInternal: false), 'internal');
      expect(status.getProblemCode(packageIsKnownInternal: true), isNull);
    });

    test('problem: insecure', () async {
      final status = await UrlChecker().checkStatus('http://pub.dev/');
      expect(status.isInvalid, false);
      expect(status.isInternal, true);
      expect(status.isSecure, false);
      expect(status.exists, true);
      expect(status.getProblemCode(packageIsKnownInternal: false), 'internal');
      expect(status.getProblemCode(packageIsKnownInternal: true), 'insecure');
    });

    test('problem: missing', () async {
      final status = await UrlChecker()
          .checkStatus('https://github.com/dart-lang/pub-dev/missing-url');
      expect(status.isInvalid, false);
      expect(status.isInternal, false);
      expect(status.isSecure, true);
      expect(status.exists, false);
      expect(status.getProblemCode(packageIsKnownInternal: false), 'missing');
      expect(status.getProblemCode(packageIsKnownInternal: true), 'missing');
    });
  });
}
