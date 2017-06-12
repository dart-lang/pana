// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:io' hide exitCode;

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'utils.dart';

class PubSummary {
  static final _solvePkgLine = new RegExp(
      r"(?:[><\+\! ]) (\w+) (\S+)(?: \((\S+) available\))?(?: from .+)?");

  final Map<String, Version> packageVersions;
  final Map<String, Version> availableVersions;
  final Map<String, Object> pubspec;

  PubSummary._(this.packageVersions, this.availableVersions, this.pubspec);

  static PubSummary create(String procStdout, {String path}) {
    var pkgVersions = <String, Version>{};
    var availVersions = <String, Version>{};

    var entries = PubEntry.parse(procStdout).where((entry) {
      if (entry.header != 'MSG') {
        return false;
      }

      return entry.content.every((line) => _solvePkgLine.hasMatch(line));
    }).toList();

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

    Map<String, Object> pubspecContent;

    if (path != null) {
      pubspecContent = yamlToJson(getPubspecContent(path));

      var theFile = new File(p.join(path, 'pubspec.lock'));
      if (theFile.existsSync()) {
        var lockFileContent = theFile.readAsStringSync();
        if (lockFileContent.isNotEmpty) {
          Map lockMap = yamlToJson(lockFileContent);
          Map pkgs = lockMap['packages'];
          if (pkgs != null) {
            var expectedPackages = pkgVersions.keys.toSet();

            pkgs.forEach((String key, Map m) {
              if (!expectedPackages.remove(key)) {
                throw new StateError(
                    "Did not parse package `$key` from pub output, "
                    "but it was found in `pubspec.lock`.");
              }

              var lockedVersion = new Version.parse(m['version']);
              if (pkgVersions[key] != lockedVersion) {
                throw new StateError(
                    "For $key, the parsed version ${pkgVersions[key]} did not "
                    "match the locked version $lockedVersion.");
              }
            });

            if (expectedPackages.isNotEmpty) {
              throw new StateError(
                  "We parsed more packaged than were found in the lock file: "
                  "${expectedPackages.join(', ')}");
            }
          }
        }
      }
    }

    return new PubSummary._(pkgVersions, availVersions, pubspecContent);
  }

  factory PubSummary.fromJson(Map<String, dynamic> json) {
    var packageVersions = _jsonMapToVersion(json['packages']);
    var availableVersions = _jsonMapToVersion(json['availablePackages']);

    return new PubSummary._(
        packageVersions, availableVersions, json['pubspecContent']);
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pubspecContent': pubspec,
        'packages': _versionMapToJson(packageVersions),
        'availablePackages': _versionMapToJson(availableVersions),
      };

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
