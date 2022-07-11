import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:pana/src/package_analysis/common.dart';
import 'package:pana/src/package_analysis/lower_bound_constraint_analysis.dart';
import 'package:pana/src/package_analysis/shapes.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart';

import '../package_server.dart';

Future<void> main() async {
  final yamlDir = Directory(path.join(
    path.current,
    'test',
    'package_analysis',
    'testdata',
    'lower_bound_constraint_issues',
  ));

  test('Missing functions and methods should be detected', () async {
    // serve dependency
    await servePackages((b) => b!
      ..serve(
        'foo',
        '1.2.4',
        pubspec: {
          'environment': {'sdk': '>=2.12.0 <3.0.0'}
        },
        contents: [
          FileDescriptor(path.join('lib', 'foo.dart'), 'void sayHello() {}')
        ],
      ));

    // root package folder
    final packageLocation = path.canonicalize(path.join(
      Directory.systemTemp.path,
      'test_package',
    ));

    if (await Directory(packageLocation).exists()) {
      throw StateError(
          'Test package folder $packageLocation already exists in temporary directory, aborting.');
    }
    await Directory(path.join(packageLocation, 'lib')).create(recursive: true);

    final pubspecString = """
name: test_package
version: 1.0.0
environment:
  sdk: '>=2.12.0 <3.0.0'
dependencies:
  foo:
    hosted:
      name: foo
      url: ${globalPackageServer!.url}
    version: ^1.2.3
""";

    // write the contents of the test package to disk
    await File(path.join(packageLocation, 'pubspec.yaml'))
        .writeAsString(pubspecString);
    await File(path.join(packageLocation, 'lib', 'main.dart'))
        .writeAsString("import 'package:foo/foo.dart';\nmain() {sayHello();}");

    await fetchDependencies(packageLocation);

    final rootSession = _PackageAnalysisContext(
      AnalysisContextCollection(includedPaths: [packageLocation])
          .contextFor(packageLocation)
          .currentSession,
    );

    final issues = await reportIssues(
      packageAnalysisSession: rootSession,
      packageLocation: packageLocation,
      rootPackageName: 'test_package',
      dependencySummaries: {
        'foo': PackageShape(
            name: 'foo',
            version: '1.2.3',
            libraries: [],
            getters: [],
            setters: [],
            functions: [],
            classes: []),
      },
      targetDependencies: await getHostedDependencies(packageLocation),
      dependencyInstalledVersions: {'foo': Version(1, 2, 4)},
    );

    expect(issues.length, equals(1));
    expect(
        issues.first,
        equals(
          LowerBoundConstraintIssue(
              dependencyPackageName: 'foo',
              constraint: VersionConstraint.parse('^1.2.3'),
              currentVersion: Version.parse('1.2.4'),
              lowestVersion: Version.parse('1.2.3'),
              identifier: 'sayHello'),
        ));

    // clean up by deleting the test package directory
    await Directory(packageLocation).delete(recursive: true);
  });
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
