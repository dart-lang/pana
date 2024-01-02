// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;

import '../internal_model.dart';
import '../logging.dart';
import '../model.dart';
import '../package_context.dart';
import '../pubspec.dart';
import '../tool/git_tool.dart';

import 'git_local_repository.dart';

const _maxPubspecBytes = 256 * 1024;

/// Returns the repository information for the current package.
Future<VerifiedRepository?> checkRepository({
  required SharedAnalysisContext sharedContext,
  required String packageName,
  required String? sourceUrl,
}) async {
  if (sourceUrl == null) {
    return null;
  }
  final parsedSourceUrl = Repository.tryParseUrl(sourceUrl);
  if (parsedSourceUrl == null) {
    return null;
  }
  var branch = parsedSourceUrl.branch;
  var completed = false;
  String? verificationFailure;
  var localPath = parsedSourceUrl.path;
  String? contributingUrl;

  Repository repositoryWithPath(String? path) {
    if (path == '' || path == '.') {
      path = null;
    }
    return Repository(
      provider: parsedSourceUrl.provider,
      host: parsedSourceUrl.host,
      repository: parsedSourceUrl.repository,
      branch: branch,
      path: path,
    );
  }

  VerifiedRepository result() {
    if (completed && verificationFailure == null) {
      return VerifiedRepository(
        repository: repositoryWithPath(localPath),
        contributingUrl: contributingUrl,
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

  if (sharedContext.options.checkRemoteRepository) {
    late GitLocalRepository repo;
    try {
      repo = await GitLocalRepository.createLocalRepository(
          parsedSourceUrl.cloneUrl);
      branch = await repo.detectDefaultBranch();

      // list all pubspec.yaml files
      final files = await repo.listFiles(branch);
      // TODO: verify all file name patterns

      final pubspecFiles =
          files.where((path) => p.basename(path) == 'pubspec.yaml').toList();
      if (pubspecFiles.isEmpty) {
        return VerifiedRepository(
          verificationFailure:
              'Could not find any `pubspec.yaml` in the repository.',
        );
      }

      Future<_PubspecMatch> matchRepoPubspecYaml(String path) async {
        late String content;
        // checkout the pubspec.yaml at the assumed location
        try {
          content = await repo.showStringContent(
            branch!,
            path,
            maxOutputBytes: _maxPubspecBytes,
          );
        } on GitToolException catch (e) {
          log.info('Unable to read "$path".', e);
          return _PubspecMatch(
              path, hasMatchingName: false, 'Unable to read `$path`: $e.');
        }
        if (content.trim().isEmpty) {
          return _PubspecMatch(
              path,
              hasMatchingName: false,
              '`$path` from the repository is empty.');
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
          return _PubspecMatch(
              path,
              hasMatchingName: false,
              '`$path` from the repository is not a valid YAML document.');
        }

        late final Pubspec gitPubspec;
        try {
          gitPubspec = Pubspec.parseYaml(content);
        } on FormatException catch (e, st) {
          log.info('Invalid pubspec content: $path', e, st);
          return _PubspecMatch(
              path,
              hasMatchingName: false,
              '`$path` from the repository is not a valid pubspec.');
        } on CheckedFromJsonException catch (e, st) {
          log.info('Invalid pubspec content: $path', e, st);
          return _PubspecMatch(
              path,
              hasMatchingName: false,
              '`$path` from the repository is not a valid pubspec.');
        }

        // verification steps
        if (gitPubspec.name != packageName) {
          return _PubspecMatch(
              path,
              hasMatchingName: false,
              '`$path` from the repository name missmatch: expected `$packageName` but got `${gitPubspec.name}`.');
        }
        final gitRepoOrHomepage = gitPubspec.repositoryOrHomepage;
        if (gitRepoOrHomepage == null) {
          return _PubspecMatch(
              path,
              hasMatchingName: true,
              '`$path` from the repository has no `repository` or `homepage` URL.');
        }
        late Repository gitRepoUrl;
        try {
          gitRepoUrl = Repository.parseUrl(gitRepoOrHomepage);
        } on FormatException catch (e) {
          return _PubspecMatch(
              path,
              hasMatchingName: true,
              '`$path` from the repository has a `repository` or `homepage` field '
              '"`$gitRepoOrHomepage`" but cannot be parsed as a repository URL: ${e.message}');
        }
        if (gitRepoUrl.cloneUrl != parsedSourceUrl.cloneUrl) {
          return _PubspecMatch(
              path,
              hasMatchingName: true,
              '`$path` from the repository URL mismatch: expected `${parsedSourceUrl.cloneUrl}` but got `${gitRepoUrl.cloneUrl}`.');
        }
        if (gitPubspec.version == null) {
          return _PubspecMatch(
              path,
              hasMatchingName: true,
              '`$path` from the repository has no `version`.');
        }
        if (gitPubspec.toJson().containsKey('publish_to')) {
          return _PubspecMatch(
              path,
              hasMatchingName: true,
              '`$path` from the repository defines `publish_to`, thus, we are unable to verify the package is published from here.');
        }

        // found no issue
        return _PubspecMatch(path, hasMatchingName: true, null);
      }

      final results = <_PubspecMatch>[];
      for (final path in pubspecFiles) {
        results.add(await matchRepoPubspecYaml(path));
      }

      final nameMatches = results.where((e) => e.hasMatchingName).toList();
      if (nameMatches.isEmpty) {
        failVerification(
            'Repository has no matching `pubspec.yaml` with `name: $packageName`.');
      } else if (nameMatches.length > 1) {
        failVerification(
            'Repository has multiple matching `pubspec.yaml` with `name: $packageName`.');
      } else {
        // confirmed name match, storing path
        localPath = p.dirname(nameMatches.single.path);

        if (nameMatches.single.verificationIssue != null) {
          failVerification(nameMatches.single.verificationIssue!);
        }

        if (verificationFailure == null) {
          final contributingCandidates = [
            if (localPath.isNotEmpty && localPath != '.')
              p.join(localPath, 'CONTRIBUTING.md'),
            'CONTRIBUTING.md',
          ];
          for (final path in contributingCandidates) {
            if (files.contains(path)) {
              final url = repositoryWithPath(null).tryResolveUrl(path);
              if (url != null) {
                final status = await sharedContext.checkUrlStatus(url);
                if (status.exists) {
                  contributingUrl = url;
                  break;
                }
              }
              break;
            }
          }
        }

        completed = true;
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
  }
  return result();
}

class _PubspecMatch {
  final String path;
  final bool hasMatchingName;
  final String? verificationIssue;

  _PubspecMatch(
    this.path,
    this.verificationIssue, {
    required this.hasMatchingName,
  });
}

extension on Repository {
  String get cloneUrl =>
      Uri(scheme: 'https', host: host, path: repository).toString();
}
