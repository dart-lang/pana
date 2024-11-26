// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Infers whether a dartdoc href is a link to a library page.
/// - pre-8.3.0 the file ended with `-library.html`
/// - with 8.3.0 the reference is a top-level directory with no slash in it
bool isHrefALibrary(String? href) {
  if (href == null || href.isEmpty) {
    return false;
  }
  // libraries before 8.3
  if (href.endsWith('-library.html')) {
    return true;
  }
  // libraries after 8.3 do not have the .html suffix in their href
  if (href.endsWith('.html')) {
    return false;
  }
  final segments = href.split('/').where((s) => s.isNotEmpty).toList();
  // libraries have only a single segment
  return segments.length == 1;
}
