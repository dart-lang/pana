// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

import '../model.dart';
import '../package_context.dart';
import '../report/_common.dart';
import '../repository/repository_url_parser.dart';

class PubspecUrlsWithIssues {
  final UrlWithIssue homepage;
  final UrlWithIssue repository;
  final UrlWithIssue issueTracker;
  final UrlWithIssue documentation;
  final List<UrlWithIssue> funding;

  PubspecUrlsWithIssues({
    required this.homepage,
    required this.repository,
    required this.issueTracker,
    required this.documentation,
    required this.funding,
  });

  Iterable<Issue> get issues => [
        homepage.issue,
        repository.issue,
        issueTracker.issue,
        documentation.issue,
        ...funding.map((i) => i.issue),
      ].whereType<Issue>();
}

class UrlWithIssue {
  final String? url;
  final Issue? issue;

  UrlWithIssue(this.url, this.issue);

  late final isOK = url != null && issue == null;
  late final isNotOK = !isOK;
  late final verifiedUrl = isOK ? url : null;
}

/// Verifies the URLs in pubspec and builds the [PubspecUrlsWithIssues] object.
Future<PubspecUrlsWithIssues> checkPubspecUrls(PackageContext context) async {
  final pubspec = context.pubspec;
  var homepage = await _checkUrlInPubspec(context, 'homepage', 'Homepage URL',
      isRequired: pubspec.repository == null);
  var repository = await _checkUrlInPubspec(
      context, 'repository', 'Repository URL',
      isRequired: pubspec.homepage == null);
  var issueTracker =
      await _checkUrlInPubspec(context, 'issue_tracker', 'Issue tracker URL');

  // Switch homepage and repository if only homepage is given,
  // and it can be verified as a valid repository.
  final verifiedRepository = await context.repository;
  final isVerifiedRepository = verifiedRepository?.repository != null;
  if (pubspec.homepage != null && pubspec.repository == null) {
    // We may switch these values if the repository has been verified, or
    // if the verification was not enabled, but the URL parsing recognizes
    // it as a valid repository.
    var maySwitch = isVerifiedRepository;
    if (!maySwitch && context.options.checkRemoteRepository == false) {
      final r = tryParseRepositoryUrl(pubspec.homepage!);
      if (r != null && r.provider != RepositoryProvider.unknown) {
        maySwitch = true;
      }
    }

    // do the actual switch
    if (maySwitch) {
      var r = repository;
      repository = homepage;
      homepage = r;
    }
  }

  // Set known issue tracker link in cases where it was not provided.
  if (pubspec.issueTracker == null && isVerifiedRepository) {
    final vr = verifiedRepository!.repository!;
    final repoSegments = vr.repository;
    if (RepositoryProvider.isGitHubCompatible(vr.provider) &&
        repoSegments != null) {
      final inferredUrl = Uri(
        scheme: 'https',
        host: vr.host,
        path: p.join(repoSegments, 'issues'),
      ).toString();
      final inferredResult = await _checkUrl(
          context, 'issue_tracker', 'Issue tracker URL', inferredUrl);
      if (inferredResult.isOK) {
        issueTracker = inferredResult;
      }
    }
  }
  final funding = <UrlWithIssue>[];
  for (final url in pubspec.funding) {
    funding.add(
        await _checkUrl(context, 'funding', 'Funding URL', url.toString()));
  }

  return PubspecUrlsWithIssues(
    homepage: homepage,
    repository: repository,
    issueTracker: issueTracker,
    documentation:
        await _checkUrlInPubspec(context, 'documentation', 'Documentation URL'),
    funding: funding,
  );
}

Future<UrlWithIssue> _checkUrlInPubspec(
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
  return await _checkUrl(context, key, name, url);
}

Future<UrlWithIssue> _checkUrl(
  PackageContext context,
  String key,
  String name,
  String url,
) async {
  final pubspec = context.pubspec;
  final status = await context.urlChecker.checkStatus(url);
  if (status.isInvalid) {
    return UrlWithIssue(
      url,
      Issue(
        "$name isn't valid.",
        span: tryGetSpanFromYamlMap(pubspec.originalYaml, key),
      ),
    );
  } else if (!status.exists) {
    return UrlWithIssue(
      url,
      Issue(
        "$name doesn't exist.",
        span: tryGetSpanFromYamlMap(pubspec.originalYaml, key),
        suggestion: 'At the time of the analysis `$url` was unreachable. '
            'Make sure that the website is reachable via [`HEAD`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/HEAD) requests.',
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
  final problemCode = status.getProblemCode();
  if (problemCode != null) {
    context.urlProblems[url] = problemCode;
  }
  return UrlWithIssue(url, null);
}
