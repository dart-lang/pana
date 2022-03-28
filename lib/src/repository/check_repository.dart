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

  Repository result() => Repository(
        baseUrl: url.baseUrl,
        branch: branch,
        packagePath: url.path.isEmpty ? null : url.path,
        isVerified: isVerified,
        verificationFailure: verificationFailure,
      );

  void failVerification(String message, [error, StackTrace? st]) {
    verificationFailure = message;
    log.info(message, error, st);
  }

  if (context.options.checkRemoteRepository) {
    isVerified = false;
    GitLocalRepository? repo;
    try {
      repo = await GitLocalRepository.createLocalRepository(url.baseUrl);
      branch ??= await repo.detectDefaultBranch();

      // list all pubspec.yaml files
      final files = await repo.listFiles(branch);
      // TODO: verify file name patterns

      final pubspecFiles =
          files.where((path) => p.basename(path) == 'pubspec.yaml').toList();
      if (pubspecFiles.isEmpty) {
        failVerification('Repository has no `pubspec.yaml`.');
        return result();
      }
      final pubspecPath = p.join(url.path, 'pubspec.yaml');
      if (!pubspecFiles.contains(pubspecPath)) {
        // TODO: detect if any of them is matching
        failVerification(
            'Repository has no `pubspec.yaml` in location: `${url.path}/`.');
        return result();
      }

      // checkout the pubspec.yaml at the assumed location
      final content = await repo.showStringContent(
        branch,
        p.join(url.path, 'pubspec.yaml'),
        maxOutputBytes: _maxPubspecBytes,
      );
      final gitPubspec = Pubspec.parseYaml(content);

      // verification steps
      if (gitPubspec.name != context.pubspec.name) {
        failVerification('Repository `pubspec.yaml` name missmatch: '
            '`${gitPubspec.name}` != `${context.pubspec.name}`.');
      } else if (gitPubspec.repositoryOrHomepage !=
          context.pubspec.repositoryOrHomepage) {
        failVerification('Repository `pubspec.yaml` URL missmatch: '
            '`${gitPubspec.repositoryOrHomepage}` != `${context.pubspec.repositoryOrHomepage}`.');
      } else if (gitPubspec.version == null) {
        failVerification('Repository `pubspec.yaml` has no version.');
      } else if (gitPubspec.toJson().containsKey('publish_to ')) {
        failVerification('Repository `pubspec.yaml` has `publish_to`.');
      }
    } on FormatException catch (e, st) {
      failVerification(
          'Unable to parse `pubspec.yaml` from git repository.', e, st);
    } on ArgumentError catch (e, st) {
      failVerification(
          'Unable to parse `pubspec.yaml` from git repository.', e, st);
    } on GitToolException catch (e, st) {
      failVerification('Unable to access git repository: ${e.message}', e, st);
    } finally {
      await repo?.delete();
    }
    isVerified = verificationFailure == null;
  }
  return result();
}
