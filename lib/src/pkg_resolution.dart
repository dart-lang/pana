// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.pkg_resolution;

import 'dart:convert';
import 'dart:io' hide exitCode;

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart' hide Pubspec;

import 'model.dart';
import 'pubspec.dart';
import 'utils.dart';

final _solvePkgLine =
    RegExp(r'(?:[><\+\! ]) (\w+) (\S+)(?: \((\S+) available\))?(?: from .+)?');

PkgResolution createPkgResolution(Pubspec pubspec, String procStdout,
    {String path}) {
  var pkgVersions = <String, Version>{};
  var availVersions = <String, Version>{};

  // first select the which match the following pattern:
  // MSG :   pkg1 [version]
  //     |   pkg2 [version] ([version] available)
  final entries = PubEntry.parse(procStdout)
      .where((entry) => entry.header == 'MSG')
      .where((entry) => entry.content.any(_solvePkgLine.hasMatch))
      .toList();

  if (entries.length == 1) {
    // normally there should be only one such content block:
    for (var match in entries.single.content
        .takeWhile(_solvePkgLine.hasMatch)
        .map(_solvePkgLine.firstMatch)) {
      var pkg = match.group(1);
      pkgVersions[pkg] = Version.parse(match.group(2));
      var availVerStr = match.group(3);
      if (availVerStr != null) {
        availVersions[pkg] = Version.parse(availVerStr);
      }
    }
  } else if (entries.length > 1) {
    throw Exception(
        'Seems that we have two sections of packages solves - weird!');
  } else {
    // it's empty – which is fine for a package with no dependencies
  }

  if (path != null) {
    _validateLockedVersions(path, pkgVersions);
  }

  final deps = _buildDeps(pubspec, pkgVersions, availVersions);
  return PkgResolution(deps);
}

void _validateLockedVersions(String path, Map<String, Version> pkgVersions) {
  var theFile = File(p.join(path, 'pubspec.lock'));
  if (theFile.existsSync()) {
    var lockFileContent = theFile.readAsStringSync();
    if (lockFileContent.isNotEmpty) {
      Map lockMap = yamlToJson(lockFileContent);
      var pkgs = lockMap['packages'] as Map<String, Object>;
      if (pkgs != null) {
        pkgs.forEach((String key, Object v) {
          var m = v as Map;
          var lockedVersion = Version.parse(m['version'] as String);
          if (pkgVersions[key] != lockedVersion) {
            throw StateError(
                'For $key, the parsed version ${pkgVersions[key]} did not '
                'match the locked version $lockedVersion.');
          }
        });
      }
    }
  }
}

List<PkgDependency> _buildDeps(Pubspec pubspec,
    Map<String, Version> pkgVersions, Map<String, Version> availVersions) {
  var loggedWeird = false;
  void logWeird(String input) {
    if (!loggedWeird) {
      // only write the header if there is "weirdness" in processing
      stderr.writeln('Package: ${pubspec.name}');
      loggedWeird = true;
    }
    // write every line of the input indented 2 spaces
    stderr.writeAll(LineSplitter.split(input).map((line) => '  $line\n'));
  }

  var deps = <PkgDependency>[];

  void addDetail(String package, Dependency dependency, String dependencyType) {
    String constraintType;
    final errors = <String>[];
    VersionConstraint constraint;
    if (dependencyType == DependencyTypes.transitive) {
      constraintType = ConstraintTypes.inherited;
    } else {
      if (dependency is SdkDependency) {
        constraintType = ConstraintTypes.sdk;
        if (dependency.sdk != 'flutter') {
          errors.add('Unsupported SDK for package $package: ${dependency.sdk}');
        }
      } else if (dependency is GitDependency) {
        constraintType = ConstraintTypes.git;
        if (dependencyType != DependencyTypes.dev) {
          errors.add('Git constraint for package $package: ${dependency.url}');
        }
      } else if (dependency is PathDependency) {
        constraintType = ConstraintTypes.path;
        errors.add('Path constraint for package $package: ${dependency.path}');
      } else if (dependency is HostedDependency) {
        constraintType = ConstraintTypes.normal;
        constraint = dependency.version;
      } else {
        constraintType = ConstraintTypes.unknown;
        errors.add('Unknown constraint for package $package:\n$dependency');
      }
    }

    var resolved = pkgVersions[package];
    var available = availVersions[package];
    if (resolved == null && dependencyType != DependencyTypes.dev) {
      errors.add('No resolved version for package $package');
    }

    if (resolved != null &&
        constraint != null &&
        !constraint.allows(resolved)) {
      errors.add(
          'Package $package has version $resolved but $constraint does not allow it!');
    }

    errors.forEach(logWeird);

    deps.add(PkgDependency(
      package: package,
      dependencyType: dependencyType,
      constraintType: constraintType,
      constraint: constraint,
      resolved: resolved,
      available: available,
      errors: errors.isEmpty ? null : errors,
    ));
  }

  final packageNames = <String>{};

  pubspec.dependencies?.forEach((k, v) {
    if (packageNames.add(k)) {
      addDetail(k, v, DependencyTypes.direct);
    }
  });

  pubspec.devDependencies?.forEach((k, v) {
    if (packageNames.add(k)) {
      addDetail(k, v, DependencyTypes.dev);
    }
  });

  pkgVersions.forEach((k, v) {
    if (packageNames.add(k)) {
      addDetail(k, null, DependencyTypes.transitive);
    }
  });

  availVersions.forEach((k, v) {
    if (packageNames.add(k)) {
      addDetail(k, null, DependencyTypes.transitive);
    }
  });

  deps.sort((a, b) => a.package.compareTo(b.package));
  return deps;
}

class PubEntry {
  static final _headerMatch = RegExp(r'^([A-Z]{2,4})[ ]{0,2}: (.*)');
  static final _lineMatch = RegExp(r'^    \|(.*)');

  final String header;
  final List<String> content;

  PubEntry(this.header, this.content);

  static Iterable<PubEntry> parse(String input) sync* {
    String header;
    List<String> entryLines;

    for (var line in LineSplitter.split(input)) {
      if (line.trim().isEmpty) {
        continue;
      }
      var match = _headerMatch.firstMatch(line);

      if (match != null) {
        if (header != null || entryLines != null) {
          assert(entryLines.isNotEmpty);
          yield PubEntry(header, entryLines);
          header = null;
          entryLines = null;
        }
        header = match[1];
        entryLines = <String>[match[2]];
      } else {
        match = _lineMatch.firstMatch(line);

        if (match == null) {
          // Likely due to Flutter silly
          // stderr.writeln("Could not parse pub line `$line`.");
          continue;
        }

        assert(entryLines != null);
        entryLines.add(match[1]);
      }
    }

    if (header != null || entryLines != null) {
      assert(entryLines.isNotEmpty);
      yield PubEntry(header, entryLines);
      header = null;
      entryLines = null;
    }
  }

  @override
  String toString() => '$header: ${content.join('\n')}';
}
