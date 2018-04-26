// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.pkg_resolution;

import 'dart:convert';
import 'dart:io' hide exitCode;

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'model.dart';
import 'pubspec.dart';
import 'utils.dart';

final _solvePkgLine = new RegExp(
    r"(?:[><\+\! ]) (\w+) (\S+)(?: \((\S+) available\))?(?: from .+)?");

PkgResolution createPkgResolution(Pubspec pubspec, String procStdout,
    {String path}) {
  var pkgVersions = <String, Version>{};
  var availVersions = <String, Version>{};

  var entries = PubEntry
      .parse(procStdout)
      .where((entry) => entry.header == 'MSG')
      .where((entry) =>
          entry.content.every((line) => _solvePkgLine.hasMatch(line)))
      .toList();

  if (entries.length == 1) {
    for (var match in entries.single.content.map(_solvePkgLine.firstMatch)) {
      var pkg = match.group(1);
      pkgVersions[pkg] = new Version.parse(match.group(2));
      var availVerStr = match.group(3);
      if (availVerStr != null) {
        availVersions[pkg] = new Version.parse(availVerStr);
      }
    }
  } else if (entries.length > 1) {
    throw "Seems that we have two sections of packages solves - weird!";
  } else {
    // it's empty – which is fine for a package with no dependencies
  }

  if (path != null) {
    _validateLockedVersions(path, pkgVersions);
  }

  final deps = _buildDeps(pubspec, pkgVersions, availVersions);
  return new PkgResolution(deps);
}

void _validateLockedVersions(String path, Map<String, Version> pkgVersions) {
  var theFile = new File(p.join(path, 'pubspec.lock'));
  if (theFile.existsSync()) {
    var lockFileContent = theFile.readAsStringSync();
    if (lockFileContent.isNotEmpty) {
      Map lockMap = yamlToJson(lockFileContent);
      Map<String, Object> pkgs = lockMap['packages'];
      if (pkgs != null) {
        pkgs.forEach((String key, Object v) {
          var m = v as Map;
          var lockedVersion = new Version.parse(m['version']);
          if (pkgVersions[key] != lockedVersion) {
            throw new StateError(
                "For $key, the parsed version ${pkgVersions[key]} did not "
                "match the locked version $lockedVersion.");
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
      stderr.writeln("Package: ${pubspec.name}");
      loggedWeird = true;
    }
    // write every line of the input indented 2 spaces
    stderr.writeAll(LineSplitter.split(input).map((line) => '  $line\n'));
  }

  var deps = <PkgDependency>[];

  /// [versionConstraint] can be a `String` or `Map`
  /// If it's a `Map` – just log and continue.
  void addDetail(String package, versionConstraint, String dependencyType) {
    String constraintType;
    final errors = <String>[];
    String constraintValue;
    if (dependencyType == DependencyTypes.transitive) {
      constraintType = ConstraintTypes.inherited;
    } else if (versionConstraint == null) {
      constraintType = ConstraintTypes.empty;
    } else if (versionConstraint is Map) {
      if (versionConstraint.containsKey('sdk')) {
        constraintType = ConstraintTypes.sdk;
        if (versionConstraint['sdk'] != 'flutter') {
          errors.add(
              'Unsupported SDK for package $package: ${versionConstraint['sdk']}');
        }
      } else if (versionConstraint.containsKey('git')) {
        constraintType = ConstraintTypes.git;
        if (dependencyType != DependencyTypes.dev) {
          errors.add(
              'Git constraint for package $package: ${versionConstraint['git']}');
        }
      } else if (versionConstraint.containsKey('path')) {
        constraintType = ConstraintTypes.path;
        errors.add(
            'Path constraint for package $package: ${versionConstraint['path']}');
      } else if (versionConstraint.containsKey('version') &&
          versionConstraint['version'] is String) {
        constraintType = ConstraintTypes.normal;
        constraintValue = versionConstraint['version'];
      } else if (versionConstraint.isEmpty) {
        constraintType = ConstraintTypes.empty;
      } else {
        constraintType = ConstraintTypes.unknown;
        errors.add(
            'Unknown constraint for package $package:\n$versionConstraint');
      }
    } else if (versionConstraint is String) {
      constraintType = ConstraintTypes.normal;
      constraintValue = versionConstraint;
    } else {
      constraintType = ConstraintTypes.unknown;
    }

    VersionConstraint constraint;
    if (constraintValue != null) {
      try {
        constraint = new VersionConstraint.parse(constraintValue);
      } catch (e) {
        errors.add(
            'Error parsing constraint for package $package: $constraintValue');
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

    deps.add(new PkgDependency(
      package,
      dependencyType,
      constraintType,
      constraint,
      resolved,
      available,
      errors.isEmpty ? null : errors,
    ));
  }

  final packageNames = new Set<String>();

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
  static final _headerMatch = new RegExp(r"^([A-Z]{2,4})[ ]{0,2}: (.*)");
  static final _lineMatch = new RegExp(r"^    \|(.*)");

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
          yield new PubEntry(header, entryLines);
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
      yield new PubEntry(header, entryLines);
      header = null;
      entryLines = null;
    }
  }

  @override
  String toString() => '$header: ${content.join('\n')}';
}
