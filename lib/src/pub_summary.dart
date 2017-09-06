// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.pub_summary;

import 'dart:collection';
import 'dart:convert';
import 'dart:io' hide exitCode;

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:json_serializable/annotations.dart';

import 'pubspec.dart';
import 'utils.dart';

part 'pub_summary.g.dart';

@JsonSerializable()
class PubSummary extends Object with _$PubSummarySerializerMixin {
  static final _solvePkgLine = new RegExp(
      r"(?:[><\+\! ]) (\w+) (\S+)(?: \((\S+) available\))?(?: from .+)?");

  @JsonKey(name: 'packages')
  final Map<String, Version> packageVersions;
  @JsonKey(name: 'availablePackages')
  final Map<String, Version> availableVersions;

  PubSummary(this.packageVersions, this.availableVersions);

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

    if (path != null) {
      var theFile = new File(p.join(path, 'pubspec.lock'));
      if (theFile.existsSync()) {
        var lockFileContent = theFile.readAsStringSync();
        if (lockFileContent.isNotEmpty) {
          Map lockMap = yamlToJson(lockFileContent);
          Map<String, Object> pkgs = lockMap['packages'];
          if (pkgs != null) {
            var expectedPackages = pkgVersions.keys.toSet();

            pkgs.forEach((String key, Object v) {
              if (!expectedPackages.remove(key)) {
                throw new StateError(
                    "Did not parse package `$key` from pub output, "
                    "but it was found in `pubspec.lock`.");
              }

              var m = v as Map;

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

    return new PubSummary(pkgVersions, availVersions);
  }

  factory PubSummary.fromJson(Map<String, dynamic> json) =>
      _$PubSummaryFromJson(json);

  Map<String, int> getStats(Pubspec pubspec) {
    // counts: direct, dev, transitive
    // outdated count, by constraint: direct, dev
    // outdated count, other: all
    var directDeps = pubspec.dependencies?.length ?? 0;
    var devDeps = pubspec.devDependencies?.length ?? 0;

    var transitiveDeps = packageVersions.length - (directDeps + devDeps);
    assert(transitiveDeps >= 0);

    var details = _getDependencyDetails(pubspec);

    var data = <String, int>{
      'deps_direct': directDeps,
      'deps_dev': devDeps,
      'deps_transitive': transitiveDeps,
      'outdated_direct': details.where((pvd) => !pvd.isDev).length,
      'outdated_dev': details.where((pvd) => pvd.isDev).length,
      'outdated_transitive': (availableVersions.keys.toSet()
            ..removeAll(details.map((pvd) => pvd.package)))
          .length,
    };

    return data;
  }

  Set<PkgDependency> _getDependencyDetails(Pubspec pubspec) {
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

    var details = new SplayTreeSet<PkgDependency>();

    /// [versionConstraint] can be a `String` or `Map`
    /// If it's a `Map` – just log and continue.
    void addDetail(String package, versionConstraint, bool isDev) {
      if (versionConstraint == null) {
        if (!isDev) {
          logWeird('BAD! No constraint provided for $package');
        }
        return;
      }

      if (versionConstraint is Map) {
        if (versionConstraint['sdk'] == 'flutter') {
          // NOOP logWeird('Flutter SDK constraint for pkg/$package');
        } else if (versionConstraint.containsKey('git') && !isDev) {
          logWeird(
              'BAD! git constraint for pkg/$package - ${versionConstraint['git']}');
        } else {
          logWeird(
              'BAD! Unknown version constraint for $package\n  $versionConstraint');
        }
        return;
      }

      var vc = new VersionConstraint.parse(versionConstraint as String);
      var usedVersion = packageVersions[package];

      if (usedVersion == null) {
        logWeird('Weird! No version for $package');
        return;
      }

      assert(vc.allows(usedVersion));

      var availableVersion = availableVersions[package];

      if (availableVersion == null) {
        return;
      }

      var added = details.add(
          new PkgDependency(package, isDev, vc, usedVersion, availableVersion));
      assert(added);
    }

    pubspec.dependencies?.forEach((k, v) {
      addDetail(k, v, false);
    });

    pubspec.devDependencies?.forEach((k, v) {
      addDetail(k, v, true);
    });

    return details;
  }
}

enum VersionResolutionType {
  /// The resolved version is the latest.
  latest,

  /// The latest version is not available due to a version constraint.
  constrained,

  /// Other, unknown?
  other,
}

@JsonSerializable()
class PkgDependency extends Object
    with _$PkgDependencySerializerMixin
    implements Comparable<PkgDependency> {
  final String package;
  final bool isDev;
  final VersionConstraint constraint;
  final Version resolved;
  final Version available;

  PkgDependency(
      this.package, this.isDev, this.constraint, this.resolved, this.available);

  factory PkgDependency.fromJson(Map<String, dynamic> json) =>
      _$PkgDependencyFromJson(json);

  VersionResolutionType get resolutionType {
    if (resolved == available) {
      return VersionResolutionType.latest;
    }

    if (constraint.allows(available)) {
      return VersionResolutionType.constrained;
    }

    if (available.isPreRelease) {
      // If the pre-release isn't allowed by the constraint, then ignore it
      // ... call it a match
      return VersionResolutionType.latest;
    }

    return VersionResolutionType.other;
  }

  @override
  int compareTo(PkgDependency other) => package.compareTo(other.package);

  @override
  String toString() {
    var items = <Object>[package];
    if (isDev) {
      items.add('(dev)');
    }
    items.add('@$resolved');

    items.add(resolutionType.toString().split('.').last);

    if (resolutionType != VersionResolutionType.latest) {
      items.add(available);
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
