import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:pana/src/package_analysis/common.dart';
import 'package:pana/src/package_analysis/lower_bound_constraint_analysis.dart';
import 'package:pana/src/package_analysis/package_analysis.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:pana/src/package_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../package_server.dart';
import 'common.dart';

Future<void> main() async {
  final yamlDir = Directory(path.join(
    path.current,
    'test',
    'package_analysis',
    'testdata',
    'lower_bound_constraint_issues',
  ));

  await for (final file in yamlDir.list()) {
    final doc = loadYaml(await (file as File).readAsString());
    final packages = doc['packages'] as List;
    test(doc['name'], () async {
      // serve all versions of the provided dependencies
      for (final package in packages) {
        final files = package['package'] as List;
        await servePackages((b) => b!
          ..serve(
            package['name'] as String,
            package['version'] as String,
            pubspec: {
              'environment': {'sdk': '>=2.12.0 <3.0.0'}
            },
            contents: files.map(descriptorFromYamlNode),
          ));
      }

      // serve the target package which the dummy will point to
      final targetYamlDependencies = doc['target']['dependencies'] as List;
      final targetYamlContent = doc['target']['package'] as List;
      await servePackages((b) => b!
        ..serve(
          'test_package',
          '1.0.0',
          pubspec: {
            'environment': {'sdk': '>=2.12.0 <3.0.0'},
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
        ));

      // create a unique temporary directory in the system temp folder
      final dummyDir = await Directory(Directory.systemTemp.path)
          .createTemp('dummy_package');
      final dummyPath = dummyDir.path;

      // write the dummy package pubspec to disk
      await File(path.join(dummyPath, 'pubspec.yaml')).writeAsString('''
name: dummy_package
version: 1.0.0
environment:
  sdk: '>=2.12.0 <3.0.0'
dependencies:
  test_package:
    hosted:
      name: test_package
      url: ${globalPackageServer!.url}
    version: 1.0.0
''');

      // fetch the dependencies of the dummy package on disk (the target package
      // and other transitive dependencies)
      await fetchDependencies(dummyPath);

      final dummyPackageAnalysisContext = PackageAnalysisContextWithStderr(
        session: AnalysisContextCollection(includedPaths: [dummyPath])
            .contextFor(dummyPath)
            .currentSession,
        packagePath: dummyPath,
        targetPackageName: 'test_package',
      );

      // collect metadata and summaries of the target's dependencies
      final dependencySummaries = <String, PackageShape>{};
      final targetDependencies = dummyPackageAnalysisContext.targetDependencies;
      for (final dependency in doc['target']['dependencies']) {
        final dependencyName = dependency['name'] as String;
        final dependencyPackages =
            packages.where((package) => package['name'] == dependencyName);

        // TODO: communicate somehow that it's necessary for the versions of any given package to be sorted in the yaml file
        // find the minimum allowed version of this package
        final allVersionsString =
            dependencyPackages.map((package) => package['version'] as String);
        final minVersion = findMinAllowedVersion(
          constraint: targetDependencies[dependencyName]!.version,
          versions: allVersionsString.map(Version.parse).toList(),
        )!;
        final dependencyMin = dependencyPackages.firstWhere(
                (package) => package['version'] == minVersion.toString());

        // TODO: can we rely on this path being empty and our testing not conflicting with physical files on disk?
        final packagePath = path.canonicalize(path.join(dependencyName));

        // set up the minimum version of this dependency in memory
        final provider = setupBasicPackage(
          packagePath: packagePath,
          packageName: dependencyName,
          packageVersion: minVersion.toString(),
        );
        for (final node in dependencyMin['package']) {
          final filePath = path.canonicalize(path.join(
            dependencyName,
            node['path'] as String,
          ));
          provider.setOverlay(
            filePath,
            content: node['content'] as String,
            modificationStamp: 0,
          );
        }

        // produce a summary of the in-memory version of this dependency
        final session = AnalysisContextCollection(
          includedPaths: [packagePath],
          resourceProvider: provider,
        ).contextFor(packagePath).currentSession;
        dependencySummaries[dependencyName] = await summarizePackage(
          context: PackageAnalysisContextWithStderr(
            session: session,
            packagePath: packagePath,
          ),
          packageName: dependencyName,
        );
      }

      // discover issues that exist in the target package
      final issues = await lowerBoundConstraintAnalysis(
        context: dummyPackageAnalysisContext,
        dependencySummaries: dependencySummaries,
      );
      final issuesString = issues.map((issue) => issue.toString()).toList();

      // fetch the list of expected regular expressions
      final expectedIssues = doc['issues'].cast<String>() as List<String>;
      expect(issuesString.length, equals(expectedIssues.length));

      // for every expected issue, remove the first element of issuesString
      // which matches that expected issue
      for (final expectedIssue in expectedIssues) {
        final matchingIndex = issuesString.indexWhere(
            (issueString) => RegExp(expectedIssue).hasMatch(issueString));
        print(issuesString[matchingIndex]);
        issuesString.removeAt(matchingIndex);
        // we expect that this regex will only match one issue
        expect(
            issuesString.indexWhere(
                (issueString) => RegExp(expectedIssue).hasMatch(issueString)),
            equals(-1));
      }

      // we expect to have removed all the elements of this List
      expect(issuesString.isEmpty, equals(true));

      // clean up by deleting the dummy package directory
      await dummyDir.delete(recursive: true);
    });
  }
}

