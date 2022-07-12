import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:pana/src/package_analysis/common.dart';
import 'package:pana/src/package_analysis/lower_bound_constraint_analysis.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:pana/src/package_analysis/summary.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart';
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

  const targetPubspecStart = '''
name: test_package
version: 1.0.0
environment:
  sdk: '>=2.12.0 <3.0.0'
dependencies:
''';

  await for (final file in yamlDir.list()) {
    final doc = loadYaml(await (file as File).readAsString());
    final packages = doc['packages'] as List;
    test(doc['name'], () async {
      // serve dependencies
      for (final package in packages) {
        final files = package['package'] as List;
        await servePackages((b) => b!
          ..serve(
            package['name'] as String,
            package['version'] as String,
            pubspec: {
              'environment': {'sdk': '>=2.12.0 <3.0.0'}
            },
            contents: files.map((package) {
              final packagePath = package['path'] as String;
              final packageContent = package['content'] as String;
              return FileDescriptor(
                path.joinAll(packagePath.split('/')),
                packageContent,
              );
            }),
          ));
      }

      // create a unique temporary directory in the system temp folder
      final targetDir =
          await Directory(Directory.systemTemp.path).createTemp('test_package');
      final targetPath = targetDir.path;

      // load dependencies into the pubspec
      var pubspecString = targetPubspecStart;
      for (final dependency in doc['target']['dependencies']) {
        pubspecString += '''
  ${dependency['name']}:
    hosted:
      name: ${dependency['name']}
      url: ${globalPackageServer!.url}
    version: ${dependency['version']}
''';
      }

      // write the contents of the test package to disk
      await File(path.join(targetPath, 'pubspec.yaml'))
          .writeAsString(pubspecString);
      for (final file in doc['target']['package']) {
        // derive absolute path of file
        final filePathRelative = file['path'] as String;
        final filePath =
            path.joinAll([targetPath, ...filePathRelative.split('/')]);

        // ensure parent directory exists
        await Directory(path.dirname(filePath)).create(recursive: true);

        // write file contents
        await File(filePath).writeAsString(file['content'] as String);
      }

      await fetchDependencies(targetPath);

      final rootPackageAnalysisContext = _PackageAnalysisContext(
        AnalysisContextCollection(includedPaths: [targetPath])
            .contextFor(targetPath)
            .currentSession,
      );

      // TODO: move this up, to the first dependencies loop?
      final dependencySummaries = <String, PackageShape>{};
      final dependencyInstalledVersions = <String, Version>{};
      final targetDependencies = await getHostedDependencies(targetPath);
      for (final dependency in doc['target']['dependencies']) {
        final dependencyName = dependency['name'] as String;
        final dependencyPackages =
            packages.where((package) => package['name'] == dependencyName);
        // TODO: communicate somehow that it's necessary for the versions of any given package to be sorted in the yaml file
        final allVersionsString =
            dependencyPackages.map((package) => package['version'] as String);
        final minVersion = findMinAllowedVersion(
          constraint: targetDependencies[dependencyName]!.version,
          versions: allVersionsString.map(Version.parse).toList(),
        )!;

        // get installed dependency version
        dependencyInstalledVersions[dependencyName] = await getInstalledVersion(
          packageAnalysisContext: rootPackageAnalysisContext,
          packageLocation: targetPath,
          dependencyName: dependencyName,
        );

        // TODO: can we rely on this path being empty and not overwriting anything?
        final packagePath = path.canonicalize(path.join(dependencyName));

        final dependencyMin = dependencyPackages.firstWhere(
            (package) => package['version'] == minVersion.toString());

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

        final session = AnalysisContextCollection(
          includedPaths: [packagePath],
          resourceProvider: provider,
        ).contextFor(packagePath).currentSession;

        dependencySummaries[dependencyName] = await summarizePackage(
          _PackageAnalysisContext(session),
          packagePath,
        );
      }

      // discover issues that exist in the target package
      final issues = await reportIssues(
        packageAnalysisContext: rootPackageAnalysisContext,
        packageLocation: targetPath,
        rootPackageName: 'test_package',
        dependencySummaries: dependencySummaries,
        targetDependencies: targetDependencies,
        dependencyInstalledVersions: dependencyInstalledVersions,
      );
      final issuesString = issues.map((issue) => issue.toString()).toList();

      // fetch the list of expected regular expressions
      final expectedIssues = doc['issues'].cast<String>() as List<String>;
      expect(issuesString.length, equals(expectedIssues.length));

      // for every expected issue, remove the first element of issuesString
      // which matches that expected issue
      for (final expectedIssue in expectedIssues) {
        // TODO: does it make sense to assume that a given regex will only match one element of issuesString?
        final matchingIndex = issuesString.indexWhere(
            (issueString) => RegExp(expectedIssue).hasMatch(issueString));
        issuesString.removeAt(matchingIndex);
      }
      // we expect to have removed all the elements of this List
      expect(issuesString.isEmpty, equals(true));

      // clean up by deleting the test package directory
      await targetDir.delete(recursive: true);
    });
  }
}

class _PackageAnalysisContext extends PackageAnalysisContext {
  @override
  late final AnalysisSession analysisSession;

  _PackageAnalysisContext(AnalysisSession session) {
    analysisSession = session;
  }

  @override
  void warning(String message) {
    stderr.writeln(message);
  }
}
