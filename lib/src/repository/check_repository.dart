// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/pubspec.dart';
import 'package:path/path.dart' as p;

import '../logging.dart';
import '../model.dart';
import '../package_context.dart';

import 'git_local_repository.dart';
import 'repository_url.dart';

const _maxPubspecBytes = 256 * 1024;

/// Returns the repository information for the current package.
Future<Repository?> checkRepository(PackageContext context) async {
  final sourceUrl = context.pubspec.repositoryOrHomepage;
  if (sourceUrl == null) {
    return null;
  }
  final url = RepositoryUrl.tryParse(sourceUrl);
  if (url == null) {
    return null;
  }
  var branch = url.branch;
  bool? isVerified;
  String? verificationFailure;
  var packagePath = url.path.isEmpty ? null : url.path;

  Repository result() {
    if (packagePath == '.') {
      packagePath = null;
    }
    return Repository(
      baseUrl: url.baseUrl,
      branch: branch,
      packagePath: packagePath,
      isVerified: isVerified,
      verificationFailure: verificationFailure,
    );
  }

  void failVerification(String message, [error, StackTrace? st]) {
    verificationFailure = message;
    log.info(message, error, st);
  }

  if (context.options.checkRemoteRepository) {
    isVerified = false;
    late GitLocalRepository repo;
    try {
      repo = await GitLocalRepository.createLocalRepository(url.baseUrl);
      branch ??= await repo.detectDefaultBranch();

      // list all pubspec.yaml files
      final files = await repo.listFiles(branch);
      // TODO: verify file name patterns

      final pubspecFiles =
          files.where((path) => p.basename(path) == 'pubspec.yaml').toList();
      if (pubspecFiles.isEmpty) {
        failVerification('Could not find any `pubspec.yaml` in the repository.');
        return result();
      }

      Future<_PubspecMatch> matchRepoPubspecYaml(String path) async {
        // checkout the pubspec.yaml at the assumed location
        final content = await repo.showStringContent(
          branch!,
          path,
          maxOutputBytes: _maxPubspecBytes,
        );
        final gitPubspec = Pubspec.parseYaml(content);
        // verification steps
        if (gitPubspec.name != context.pubspec.name) {
          return _PubspecMatch(
              path,
              false,
              'Repository `$path` name missmatch: '
              '`${gitPubspec.name}` != `${context.pubspec.name}`.');
        }
        final gitRepoOrHomepage = gitPubspec.repositoryOrHomepage;
        if (gitRepoOrHomepage == null) {
          return _PubspecMatch(path, true,
              'Repository `$path` has no `repository` or `homepage` URL.');
        }
        final gitRepoUrl = RepositoryUrl.tryParse(gitRepoOrHomepage);
        if (gitRepoUrl?.baseUrl != url.baseUrl) {
          return _PubspecMatch(path, true,
              'Repository `$path` URL missmatch: expected `${url.baseUrl}` but got `${gitRepoUrl?.baseUrl}`.');
        }
        if (gitPubspec.version == null) {
          return _PubspecMatch(
              path, true, 'Repository `$path` has no version.');
        }
        if (gitPubspec.toJson().containsKey('publish_to')) {
          return _PubspecMatch(
              path, true, '`$path/pubspec.yaml` from the repository defines `publish_to`, thus, we are unable to verify the package is published from here.');
        }

        // found no issue
        return _PubspecMatch(path, true);
      }

      final results = <_PubspecMatch>[];
      for (final path in pubspecFiles) {
        results.add(await matchRepoPubspecYaml(path));
      }

      final nameMatches = results.where((e) => e.hasMatchingName).toList();
      if (nameMatches.isEmpty) {
        failVerification(
            'Repository has no matching `pubspec.yaml` with `name: ${context.pubspec.name}`.');
      } else if (nameMatches.length > 1) {
        failVerification(
            'Repository has multiple matching `pubspec.yaml` with `name: ${context.pubspec.name}`.');
      } else {
        // confirmed name match, storing path
        packagePath = p.dirname(nameMatches.single.path);

        if (nameMatches.single.verificationIssue != null) {
          failVerification(nameMatches.single.verificationIssue!);
        }
      }
    } on FormatException catch (e, st) {
      failVerification(
          'Unable to parse `pubspec.yaml` from git repository. $e', e, st);
    } on ArgumentError catch (e, st) {
      failVerification(
          'Unable to parse `pubspec.yaml` from git repository. $e', e, st);
    } on GitToolException catch (e, st) {
      failVerification('Unable to access git repository: ${e.message}', e, st);
    } finally {
      await repo.delete();
    }
    isVerified = verificationFailure == null;
  }
  return result();
}

class _PubspecMatch {
  final String path;
  final bool hasMatchingName;
  final String? verificationIssue;

  _PubspecMatch(this.path, this.hasMatchingName, [this.verificationIssue]);
}
