// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pana/src/pubspec.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;

import '../logging.dart';
import '../model.dart';
import '../package_context.dart';

import 'git_local_repository.dart';

const _maxPubspecBytes = 256 * 1024;

class VerifiedRepository {
  final Repository? repository;
  final String? verificationFailure;

  VerifiedRepository({
    this.repository,
    this.verificationFailure,
  });
}

/// Returns the repository information for the current package.
Future<VerifiedRepository?> checkRepository(PackageContext context) async {
  final sourceUrl = context.pubspec.repositoryOrHomepage;
  if (sourceUrl == null) {
    return null;
  }
  final url = Repository.tryParseUrl(sourceUrl);
  if (url == null) {
    return null;
  }
  var branch = url.branch;
  var isVerified = false;
  String? verificationFailure;
  var localPath = url.path;

  VerifiedRepository result() {
    if (localPath == '.') {
      localPath = null;
    }
    if (isVerified && verificationFailure == null) {
      return VerifiedRepository(
        repository: Repository(
          provider: url.provider,
          host: url.host,
          repository: url.repository,
          branch: branch,
          path: localPath,
        ),
      );
    } else {
      return VerifiedRepository(
        verificationFailure: verificationFailure,
      );
    }
  }

  void failVerification(String message, [error, StackTrace? st]) {
    verificationFailure = message;
    log.info(message, error, st);
  }

  if (context.options.checkRemoteRepository) {
    isVerified = false;
    late GitLocalRepository repo;
    try {
      repo = await GitLocalRepository.createLocalRepository(url.cloneUrl);
      branch = await repo.detectDefaultBranch();

      // list all pubspec.yaml files
      final files = await repo.listFiles(branch);
      // TODO: verify all file name patterns

      final pubspecFiles =
          files.where((path) => p.basename(path) == 'pubspec.yaml').toList();
      if (pubspecFiles.isEmpty) {
        failVerification(
            'Could not find any `pubspec.yaml` in the repository.');
        return result();
      }

      Future<_PubspecMatch> matchRepoPubspecYaml(String path) async {
        // checkout the pubspec.yaml at the assumed location
        final content = await repo.showStringContent(
          branch!,
          path,
          maxOutputBytes: _maxPubspecBytes,
        );
        if (content.trim().isEmpty) {
          return _PubspecMatch(
              path, false, '`$path` from the repository is empty.');
        }
        // TODO: consider to allow the exceptions to pass here, to allow an
        //       unrelated, but badly formatted pubspec.yaml in the repository.
        // ignore: prefer_typing_uninitialized_variables
        var yamlDoc;
        try {
          yamlDoc = yaml.loadYaml(content);
        } on FormatException catch (e, st) {
          log.info('Invalid yaml file: $path', e, st);
        } on ArgumentError catch (e, st) {
          log.info('Invalid yaml file: $path', e, st);
        }
        if (yamlDoc == null) {
          return _PubspecMatch(path, false,
              '`$path` from the repository is not a valid YAML document.');
        }

        late final Pubspec gitPubspec;
        try {
          gitPubspec = Pubspec.parseYaml(content);
        } on FormatException catch (e, st) {
          log.info('Invalid pubspec content: $path', e, st);
          return _PubspecMatch(path, false,
              '`$path` from the repository is not a valid pubspec.');
        } on CheckedFromJsonException catch (e, st) {
          log.info('Invalid pubspec content: $path', e, st);
          return _PubspecMatch(path, false,
              '`$path` from the repository is not a valid pubspec.');
        }

        // verification steps
        if (gitPubspec.name != context.pubspec.name) {
          return _PubspecMatch(path, false,
              '`$path` from the repository name missmatch: expected `${context.pubspec.name}` but got `${gitPubspec.name}`.');
        }
        final gitRepoOrHomepage = gitPubspec.repositoryOrHomepage;
        if (gitRepoOrHomepage == null) {
          return _PubspecMatch(path, true,
              '`$path` from the repository has no `repository` or `homepage` URL.');
        }
        final gitRepoUrl = Repository.tryParseUrl(gitRepoOrHomepage);
        if (gitRepoUrl?.cloneUrl != url.cloneUrl) {
          return _PubspecMatch(path, true,
              '`$path` from the repository URL missmatch: expected `${url.cloneUrl}` but got `${gitRepoUrl?.cloneUrl}`.');
        }
        if (gitPubspec.version == null) {
          return _PubspecMatch(
              path, true, '`$path` from the repository has no `version`.');
        }
        if (gitPubspec.toJson().containsKey('publish_to')) {
          return _PubspecMatch(path, true,
              '`$path` from the repository defines `publish_to`, thus, we are unable to verify the package is published from here.');
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
        localPath = p.dirname(nameMatches.single.path);

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

extension on Repository {
  String get cloneUrl =>
      Uri(scheme: 'https', host: host, path: repository).toString();
}
