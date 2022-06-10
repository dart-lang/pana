// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../package_context.dart';
import '../report/_common.dart';

class PubspecUrlsWithIssues {
  final UrlWithIssue homepage;
  final UrlWithIssue repository;
  final UrlWithIssue issueTracker;
  final UrlWithIssue documentation;

  PubspecUrlsWithIssues({
    required this.homepage,
    required this.repository,
    required this.issueTracker,
    required this.documentation,
  });

  Iterable<Issue> get issues => [
        homepage.issue,
        repository.issue,
        issueTracker.issue,
        documentation.issue,
      ].whereType<Issue>();
}

class UrlWithIssue {
  final String? url;
  final Issue? issue;

  UrlWithIssue(this.url, this.issue);

  late final isOK = url != null && issue == null;
  late final verifiedUrl = isOK ? url : null;
}

/// Verifies the URLs in pubspec and builds the [PubspecUrlsWithIssues] object.
Future<PubspecUrlsWithIssues> checkPubspecUrls(PackageContext context) async {
  final pubspec = context.pubspec;
  return PubspecUrlsWithIssues(
    homepage: await _checkUrl(context, 'homepage', 'Homepage URL',
        isRequired: pubspec.repository == null),
    repository: await _checkUrl(context, 'repository', 'Repository URL',
        isRequired: pubspec.homepage == null),
    issueTracker:
        await _checkUrl(context, 'issue_tracker', 'Issue tracker URL'),
    documentation:
        await _checkUrl(context, 'documentation', 'Documentation URL'),
  );
}

Future<UrlWithIssue> _checkUrl(
  PackageContext context,
  String key,
  String name, {
  bool isRequired = false,
}) async {
  final pubspec = context.pubspec;
  final content = pubspec.originalYaml[key];
  if (content != null && content is! String) {
    return UrlWithIssue(
      null,
      Issue('The `$key` entry, if present, should be a string containing a url',
          span: tryGetSpanFromYamlMap(pubspec.originalYaml, key)),
    );
  }
  final url = content as String?;

  if (url == null || url.isEmpty) {
    if (isRequired) {
      return UrlWithIssue(
          null, Issue("`pubspec.yaml` doesn't have a `$key` entry."));
    }
    return UrlWithIssue(null, null);
  }

  final status = await context.urlChecker.checkStatus(url);
  if (status.isInvalid) {
    return UrlWithIssue(
      url,
      Issue(
        "$name isn't valid.",
        span: tryGetSpanFromYamlMap(pubspec.originalYaml, key),
      ),
    );
  } else if (status.isInternal && !context.options.isInternal) {
    return UrlWithIssue(
      url,
      Issue(
        "$name isn't helpful.",
        span: tryGetSpanFromYamlMap(pubspec.originalYaml, key),
      ),
    );
  } else if (!status.exists) {
    return UrlWithIssue(
      url,
      Issue(
        "$name doesn't exist.",
        span: tryGetSpanFromYamlMap(pubspec.originalYaml, key),
        suggestion: 'At the time of the analysis `$url` was unreachable.',
      ),
    );
  } else if (!status.isSecure) {
    return UrlWithIssue(
      url,
      Issue(
        '$name is insecure.',
        span: tryGetSpanFromYamlMap(pubspec.originalYaml, key),
        suggestion: 'Update the `$key` field and use a secure (`https`) URL.',
      ),
    );
  }
  final problemCode =
      status.getProblemCode(packageIsKnownInternal: context.options.isInternal);
  if (problemCode != null) {
    context.urlProblems[url] = problemCode;
  }
  return UrlWithIssue(url, null);
}
