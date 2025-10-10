// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:safe_url_check/safe_url_check.dart';

import 'internal_model.dart' show UrlStatus;
import 'version.dart';

export 'internal_model.dart' show UrlStatus;

/// Checks if an URL is valid and accessible.
class UrlChecker {
  /// Returns `true` if the [uri] exists,
  /// `false` if getting the page encountered problems.
  ///
  /// A cached [UrlChecker] implementation should override this method,
  /// wrap it in a cached callback, still invoking it via `super.checkUrlExists()`.
  Future<bool> checkUrlExists(Uri uri) async {
    return await safeUrlCheck(
      uri,
      userAgent: 'pana/$packageVersion (https://pub.dev/packages/pana)',
    );
  }

  /// Check the status of the URL, using validity checks, cache and
  /// safe URL checks with limited number of redirects.
  Future<UrlStatus> checkStatus(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return UrlStatus.invalid();
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return UrlStatus.invalid();
    }
    // The safe URL check will verify if the resolved IP of the host name
    // seems to be valid (e.g. not an a local loopback, multicast or private network).
    final exists = await checkUrlExists(uri);
    return UrlStatus(
      isInvalid: false,
      isSecure: uri.scheme == 'https',
      exists: exists,
    );
  }
}
