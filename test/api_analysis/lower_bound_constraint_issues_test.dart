// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/src/api_analysis/lower_bound_constraint_analysis.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../package_server.dart';
import 'common.dart';

Future<void> main() async {
  final yamlDir = Directory(path.join(
    path.current,
    'test',
    'api_analysis',
    'testdata',
    'lower_bound_constraint_issues',
  ));

  await for (final file in yamlDir.list()) {
    final doc = loadYaml(await (file as File).readAsString());
    final releases = doc['releases'] as List;
    test(doc['name'], () async {
      // Create a unique temporary directory to serve as the pub cache for this test.
      final tempPubCache = await Directory(Directory.systemTemp.path)
          .createTemp('pub_cache_temp');

      // Set up package server.
      await serveNoPackages();

      // Serve all versions of the provided dependencies (the releases).
      for (final release in releases) {
        final files = release['package'] as List;
        globalPackageServer!.add(
          (b) => b!.serve(
            release['name'] as String,
            release['version'] as String,
            pubspec: {
              'environment': {'sdk': '>=2.13.0 <3.0.0'}
            },
            contents: files.map(descriptorFromYamlNode),
          ),
        );
      }

      // Serve the target package to which the dummy will point.
      final targetYamlDependencies = doc['target']['dependencies'] as List;
      final targetYamlContent = doc['target']['package'] as List;
      globalPackageServer!.add(
        (b) => b!.serve(
          'test.package',
          '1.0.0',
          pubspec: {
            'environment': {'sdk': '>=2.13.0 <3.0.0'},
            'dependencies': Map.fromEntries(
              targetYamlDependencies.map(
                (dependency) => MapEntry(
                  dependency['name'],
                  {
                    'hosted': {
                      'name': dependency['name'],
                      'url': globalPackageServer!.url,
                    },
                    'version': dependency['version']
                  },
                ),
              ),
            ),
          },
          contents: targetYamlContent.map(descriptorFromYamlNode),
        ),
      );

      // Create a unique temporary directory for the dummy package.
      final dummyDir = await Directory(Directory.systemTemp.path)
          .createTemp('dummy_package');
      final dummyPath = dummyDir.path;

      // Discover issues that exist in the target package.
      final issues = await lowerBoundConstraintAnalysis(
        targetName: 'test.package',
        tempPath: dummyPath,
        pubHostedUrl: globalPackageServer!.url,
        pubCachePath: tempPubCache.path,
      );
      final issuesString = issues.map((issue) => issue.toString()).toList();

      // Fetch the list of expected regular expressions.
      final expectedIssues = doc['issues'].cast<String>() as List<String>;
      expect(issuesString.length, equals(expectedIssues.length));

      // For every expected issue, remove the first element of [issuesString]
      // which matches that expected issue.
      for (final expectedIssue in expectedIssues) {
        final matchingIndex = issuesString.indexWhere(
            (issueString) => RegExp(expectedIssue).hasMatch(issueString));
        issuesString.removeAt(matchingIndex);
        // Expect that this regex will only match one issue.
        expect(
            issuesString.indexWhere(
                (issueString) => RegExp(expectedIssue).hasMatch(issueString)),
            equals(-1));
      }

      // Expect to have removed all the elements of this [List].
      expect(issuesString.isEmpty, equals(true));

      // Clean up by deleting the temp pub cache and the dummy package
      // directories, and closing the server.
      await dummyDir.delete(recursive: true);
      await tempPubCache.delete(recursive: true);
      await globalPackageServer!.close();
    });
  }
}
