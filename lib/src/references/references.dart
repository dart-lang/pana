// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../model.dart';
import '../package_context.dart';

Future<References> createReferences(PackageContext context) async {
  final pubspecUrls = await context.pubspecUrlsWithIssues;
  return References(
    homepageUrl: pubspecUrls.homepage.verifiedUrl,
    repositoryUrl: pubspecUrls.repository.verifiedUrl,
    issueTrackerUrl: pubspecUrls.issueTracker.verifiedUrl,
    documentationUrl: pubspecUrls.documentation.verifiedUrl,
  );
}
