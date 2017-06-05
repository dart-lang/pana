// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'utils.dart';

final _prefix = new RegExp(r"(MSG|  ) (:|\|) (?:\+| ) (.+)");
final _infoRegexp =
    new RegExp(r"(\w+) (\S+)(?: \((\S+) available\))?(?: from .+)?");

class PubSummary {
  final int exitCode;
  final String stdoutValue;
  final String stderrValue;
  final String lockFileContent;
  final Map<String, Version> packageVersions;
  final Map<String, Version> availableVersions;
  final Map<String, Version> lockedVersions;
  final Map<String, Object> pubspec;

  PubSummary._(
      this.exitCode,
      this.stdoutValue,
      this.stderrValue,
      this.packageVersions,
      this.availableVersions,
      this.lockedVersions,
      String pubspecContent,
      this.lockFileContent)
      : pubspec = yamlToJson(pubspecContent);

  static PubSummary create(
      int exitCode, String procStdout, String procStderr, String path) {
    Map<String, Version> pkgVersions;
    Map<String, Version> availVersions;

    if (exitCode == 0) {
      pkgVersions = <String, Version>{};
      availVersions = <String, Version>{};

      for (var match in LineSplitter
          .split(procStdout)
          .map((l) => _prefix.firstMatch(l)?.group(3))
          .where((m) => m != null)
          .map((l) {
        var allMatches = _infoRegexp.allMatches(l).toList();
        if (allMatches.length > 1) {
          throw "Weird! – can't parse '$l'";
        }
        return _infoRegexp.allMatches(l).single;
      })) {
        var pkg = match.group(1);

        pkgVersions[pkg] = new Version.parse(match.group(2));

        var availVerStr = match.group(3);

        if (availVerStr != null) {
          availVersions[pkg] = new Version.parse(availVerStr);
        }
      }
    }

    String pubspecContent, lockFileContent;
    Map<String, Version> lockedVersions;
    if (path != null) {
      pubspecContent = getPubspecContent(path);

      var theFile = new File(p.join(path, 'pubspec.lock'));
      if (theFile.existsSync()) {
        lockFileContent = theFile.readAsStringSync();
        if (lockFileContent.isNotEmpty) {
          Map lockMap = yamlToJson(lockFileContent);
          Map pkgs = lockMap['packages'];
          if (pkgs != null) {
            lockedVersions = {};
            pkgs.forEach((String key, Map m) {
              lockedVersions[key] = new Version.parse(m['version']);
            });
          }
        }
      }
    }

    if (exitCode != 0 && procStderr != null && procStderr.trim().isNotEmpty) {
      stderr.writeln(procStderr.trim());
    }

    return new PubSummary._(exitCode, procStdout, procStderr, pkgVersions,
        availVersions, lockedVersions, pubspecContent, lockFileContent);
  }

  factory PubSummary.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('packages')) {
      var pubspecContent = json['pubspecContent'];
      var packageVersions = _jsonMapToVersion(json['packages']);
      var availableVersions = _jsonMapToVersion(json['availablePackages']);
      var lockedVersions = _jsonMapToVersion(json['lockedVersions']);

      return new PubSummary._(
        0,
        '', // stdout
        '', // stderr
        packageVersions,
        availableVersions,
        lockedVersions,
        JSON.encode(pubspecContent),
        '', // lock file content
      );
    }

    return new PubSummary._(json['exitCode'], json['stdout'], json['stderr'],
        null, null, null, null, null);
  }

  Map<String, int> getStats() {
    // counts: direct, dev, transitive
    // outdated count, by constraint: direct, dev
    // outdated count, other: all

    var directDeps = (pubspec['dependencies'] as Map ?? {}).length;
    var devDeps = (pubspec['dev_dependencies'] as Map ?? {}).length;

    var transitiveDeps = packageVersions.length - (directDeps + devDeps);
    assert(transitiveDeps >= 0);

    var details = getDependencyDetails();

    var data = <String, int>{
      'deps_direct': directDeps,
      'deps_dev': devDeps,
      'deps_transitive': transitiveDeps,
      'outdated_direct': details.where((pvd) => !pvd.isDevDep).length,
      'outdated_dev': details.where((pvd) => pvd.isDevDep).length,
      'outdated_transitive': (availableVersions.keys.toSet()
            ..removeAll(details.map((pvd) => pvd.package)))
          .length,
    };

    return data;
  }

  /// Can be `null` if there is no [pubspec].
  Set<PkgVersionDetails> getDependencyDetails() {
    if (pubspec == null) {
      return null;
    }

    var details = new SplayTreeSet<PkgVersionDetails>();

    /// [versionConstraint] can be a `String` or `Map`
    /// If it's a `Map` – just log and continue.
    void addDetail(String package, versionConstraint, bool isDev) {
      if (versionConstraint == null) {
        stderr.writeln('No constraint provided for $package');
        return;
      }

      if (versionConstraint is Map) {
        stderr.writeln(
            'Non-versioned constraint for $package\n  $versionConstraint');
        return;
      }

      var vc = new VersionConstraint.parse(versionConstraint as String);
      var usedVersion = packageVersions[package];

      if (usedVersion == null) {
        stderr.writeln('Weird! No version for $package');
        return;
      }

      assert(vc.allows(usedVersion));

      var availableVersion = availableVersions[package];

      if (availableVersion == null) {
        return;
      }

      var added = details.add(new PkgVersionDetails._(
          package, isDev, vc, usedVersion, availableVersion));
      assert(added);
    }

    (pubspec['dependencies'] as Map ?? {}).forEach((k, v) {
      addDetail(k, v, false);
    });

    (pubspec['dev_dependencies'] as Map ?? {}).forEach((k, v) {
      addDetail(k, v, true);
    });

    return details;
  }

  List<String> get authors {
    var authors = <String>[];

    if (pubspec == null) {
      return authors;
    }

    if (pubspec['author'] != null) {
      authors.add(pubspec['author']);
    } else if (pubspec['authors'] != null) {
      authors.addAll(pubspec['authors'] as List<String>);
    }

    return authors;
  }

  Version get pkgVersion => new Version.parse(pubspec['version']);

  Map<String, dynamic> toJson() {
    if (exitCode == 0) {
      return <String, dynamic>{
        'pubspecContent': pubspec,
        'packages': _versionMapToJson(packageVersions),
        'lockedVersions': _versionMapToJson(lockedVersions),
        'availablePackages': _versionMapToJson(availableVersions),
      };
    } else {
      return <String, dynamic>{
        'exitCode': exitCode,
        'stdout': stdoutValue,
        'stderr': stderrValue
      };
    }
  }

  static Map<String, dynamic> _versionMapToJson(Map<String, Version> input) =>
      new Map<String, String>.fromIterable(input?.keys ?? [],
          value: (String i) => input[i].toString());

  static Map<String, dynamic> _jsonMapToVersion(Map<String, String> input) =>
      new Map<String, Version>.fromIterable(input?.keys ?? [],
          value: (String i) => new Version.parse(input[i]));
}

enum PkgVersionDetailType { match, missLatestByConstraint, missLatestByOther }

class PkgVersionDetails implements Comparable<PkgVersionDetails> {
  final String package;
  final bool isDevDep;
  final VersionConstraint constraint;
  final Version usedVersion;
  final Version availableVersion;

  PkgVersionDetails._(this.package, this.isDevDep, this.constraint,
      this.usedVersion, this.availableVersion);

  PkgVersionDetailType get type {
    if (usedVersion == availableVersion) {
      return PkgVersionDetailType.match;
    }

    if (constraint.allows(availableVersion)) {
      return PkgVersionDetailType.missLatestByConstraint;
    }

    if (availableVersion.isPreRelease) {
      // If the pre-release isn't allowed by the constraint, then ignore it
      // ... call it a match
      return PkgVersionDetailType.match;
    }

    return PkgVersionDetailType.missLatestByOther;
  }

  @override
  int compareTo(PkgVersionDetails other) => package.compareTo(other.package);

  @override
  String toString() {
    var items = <Object>[package];
    if (isDevDep) {
      items.add('(dev)');
    }
    items.add('@$usedVersion');

    items.add(type.toString().split('.').last);

    if (type != PkgVersionDetailType.match) {
      items.add(availableVersion);
    }
    return items.join(' ');
  }
}
