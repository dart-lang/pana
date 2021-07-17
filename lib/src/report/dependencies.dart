// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart'
    show
        Dependency,
        GitDependency,
        HostedDependency,
        PathDependency,
        SdkDependency;

import '../internal_model.dart';
import '../logging.dart';
import '../model.dart';
import '../package_context.dart';
import '../pubspec.dart';
import '../sdk_env.dart';
import '../utils.dart';

import '_common.dart';

Future<ReportSection> trustworthyDependency(PackageContext context) async {
  final pubspec = context.pubspec;
  final packageDir = context.packageDir;
  final toolEnvironment = context.toolEnvironment;

  Future<Subsection> dependencies() async {
    final issues = <Issue>[];
    var bodyPrefix = '';
    var points = 10;
    var status = ReportStatus.passed;
    if (context.pubspecAllowsCurrentSdk) {
      try {
        final outdated = Outdated.fromJson(await toolEnvironment.runPubOutdated(
          packageDir,
          args: [
            '--json',
            '--up-to-date',
            '--no-dev-dependencies',
            '--no-dependency-overrides',
          ],
        ));
        final outdatedVersions = <String, List<OutdatedVersionDescription>>{};
        for (final p in outdated.packages) {
          outdatedVersions[p.package] =
              await computeOutdatedVersions(context, p);
        }
        String constraint(Dependency dependency) {
          if (dependency is HostedDependency) {
            return '`${dependency.version}`';
          } else if (dependency is SdkDependency) {
            return '`${dependency.sdk}`';
          } else if (dependency is GitDependency) {
            return '`${dependency.ref}`';
          } else if (dependency is PathDependency) {
            return '`${dependency.path}`';
          } else {
            return '-';
          }
        }

        String makeTable(List<List<String>> rows) {
          return [
            ['Package', 'Constraint', 'Compatible', 'Latest'],
            [':-', ':-', ':-', ':-'],
            ...rows,
          ].map((r) => '|${r.join('|')}|').join('\n');
        }

        final links = <String>[];
        String linkToPackage(String pkg) {
          final link = '[`$pkg`]: https://pub.dev/packages/$pkg';
          if (!links.contains(link)) {
            links.add(link);
          }
          return '[`$pkg`]';
        }

        final depsTable = outdated.packages
            .where((p) => pubspec.dependencies.containsKey(p.package))
            .map((p) => [
                  linkToPackage(p.package),
                  constraint(pubspec.dependencies[p.package]!),
                  p.upgradable?.version ?? '-',
                  if (outdatedVersions.containsKey(p.package) &&
                      outdatedVersions[p.package]!.isNotEmpty)
                    '**${p.latest?.version ?? '-'}**'
                  else
                    p.latest?.version ?? '-',
                ])
            .toList();

        final transitiveTable = outdated.packages
            .where((p) => !pubspec.dependencies.containsKey(p.package))
            // See: https://github.com/dart-lang/pub/issues/2552
            .where((p) => p.upgradable != null)
            .map((p) => [
                  linkToPackage(p.package),
                  '-',
                  p.upgradable?.version ?? '-',
                  p.latest?.version ?? '-',
                ])
            .toList();

        bodyPrefix = [
          // If we have deps show table
          if (depsTable.isNotEmpty) ...[
            makeTable(depsTable),
            '',
          ] else ...[
            'No dependencies.',
            '',
          ],
          // If we have transitive deps too
          if (transitiveTable.isNotEmpty) ...[
            '<details><summary>Transitive dependencies</summary>',
            '',
            makeTable(transitiveTable),
            '</details>',
            '',
          ],
          'To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.',
          '',
          if (links.isNotEmpty) ...[
            ...links,
            '',
          ],
        ].join('\n');
        for (final l in outdatedVersions.values) {
          if (l.isNotEmpty) {
            final worst = maxBy<OutdatedVersionDescription>(
                l, (a, b) => a.status.index - b.status.index);
            issues.add(worst.issue);
            if (worst.status == OutdatedStatus.outdated) {
              points = 0;
              status = ReportStatus.failed;
            } else if (worst.status == OutdatedStatus.outdatedByPreview ||
                worst.status == OutdatedStatus.outdatedByRecent) {
              // TODO(sigurdm): Could we find some way of indicating that
              // points will be lost soon?
              status = ReportStatus.passed;
            }
          }
        }
      } on ToolException catch (e) {
        issues.add(Issue('Could not run `dart pub outdated`: ${e.message}'));
        points = 0;
        status = ReportStatus.failed;
      }
    } else {
      issues.add(_unsupportedDartSdk(context, command: 'dart pub outdated'));
      points = 0;
      status = ReportStatus.failed;
    }

    return Subsection(
      'All of the package dependencies are supported in the latest version',
      issues,
      points,
      10,
      status,
      bodyPrefix: bodyPrefix,
    );
  }

  Future<Subsection> sdkSupport() async {
    final issues = <Issue>[];
    final sdkConstraint = pubspec.dartSdkConstraint;
    if (sdkConstraint == null) {
      issues.add(Issue('Pubspec.yaml does not have an sdk version constraint.',
          suggestion: 'Try adding an sdk constraint to your `pubspec.yaml`'));
    } else if (!context.pubspecAllowsCurrentSdk) {
      issues.add(_unsupportedDartSdk(context,
          suggestion: 'Try widening the upper boundary of the constraint.'));
    }

    final runtimeInfo = toolEnvironment.runtimeInfo;
    final usesFlutter = pubspec.usesFlutter;

    if (usesFlutter) {
      if (!runtimeInfo.hasFlutter) {
        issues.add(Issue(
            'Found no Flutter in your PATH. Could not determine the current Flutter version.'));
      } else {

        final flutterDartVersion =
            Version.parse(runtimeInfo.flutterInternalDartSdkVersion!);
        final allowsCurrentFlutterDart =
            sdkConstraint?.allows(flutterDartVersion) ?? false;

        if (!allowsCurrentFlutterDart) {
          issues.add(
            Issue(
              'The current SDK constraint does not allow the Dart version used by the latest stable Flutter ($flutterDartVersion)',
              span: tryGetSpanFromYamlMap(pubspec.environment, 'sdk'),
            ),
          );
        } else {
          // TODO(sigurdm): this will not work well locally (installed version will
          // not be latest). Perhaps we should query somewhere for the latest version.
          final currentFlutterVersion = runtimeInfo.flutterVersion == null
              ? null
              : Version.parse(runtimeInfo.flutterVersion!);
          final flutterConstraint = pubspec.flutterSdkConstraint;
          if (flutterConstraint != null &&
              currentFlutterVersion != null &&
              !flutterConstraint.allows(currentFlutterVersion)) {
            issues.add(
              Issue(
                'The current flutter constraint does not allow the latest Flutter ($currentFlutterVersion)',
                span: tryGetSpanFromYamlMap(pubspec.environment, 'flutter'),
              ),
            );
          }
        }
      }
    }
    final status = issues.isEmpty ? ReportStatus.passed : ReportStatus.failed;
    final points = issues.isEmpty ? 10 : 0;
    return Subsection(
      'Package supports latest stable Dart and Flutter SDKs',
      issues,
      points,
      10,
      status,
    );
  }

  final dependencySection = await dependencies();
  final sdkSection = await sdkSupport();
  final subsections = [dependencySection, sdkSection];
  return makeSection(
    id: ReportSectionId.dependency,
    title: 'Support up-to-date dependencies',
    maxPoints: 20,
    subsections: subsections,
    basePath: packageDir,
  );
}

Issue _unsupportedDartSdk(PackageContext context,
    {String? command, String? suggestion}) {
  final msg = StringBuffer(
      "Sdk constraint doesn't support current Dart version ${context.currentSdkVersion}.");
  if (command != null) {
    msg.write(' Cannot run `$command`.');
  }
  return Issue(
    msg.toString(),
    span: tryGetSpanFromYamlMap(context.pubspec.environment, 'sdk'),
    suggestion: suggestion,
  );
}

enum OutdatedStatus { outdated, outdatedByRecent, outdatedByPreview }

class OutdatedVersionDescription {
  final Issue issue;
  final OutdatedStatus status;
  OutdatedVersionDescription(this.issue, this.status);
}

/// Returns a list of stable unsupported versions newer than "upgradable", along
/// with "how badly" it is outdated.
Future<List<OutdatedVersionDescription>> computeOutdatedVersions(
    PackageContext context, OutdatedPackage package) async {
  const acceptableUpdateDelay = Duration(days: 30);
  T? tryGetFromJson<T>(Map<String, dynamic> json, String key) {
    final element = json[key];
    return element is T ? element : null;
  }

  final name = package.package;
  final latest = package.latest?.version;
  if (!context.pubspec.dependencies.containsKey(name) || latest == null) {
    return [];
  }
  final latestVersion = Version.parse(latest);
  final dependency = context.pubspec.dependencies[name];
  if (dependency is! HostedDependency) {
    return [];
  }
  final hostedDependency = dependency;
  if (hostedDependency.version.allows(latestVersion)) {
    return [];
  }
  final result = <OutdatedVersionDescription>[];

  final versionListing = jsonDecode(await getVersionListing(
    name,
    pubHostedUrl: hostedDependency.hosted?.url,
  ));

  try {
    final versions = tryGetFromJson<List>(
        versionListing as Map<String, dynamic>, 'versions');
    if (versions == null) {
      // Bad response from pub host.
      return [];
    }
    for (final version in versions) {
      if (version is Map<String, dynamic>) {
        final versionString = tryGetFromJson<String>(version, 'version');
        if (versionString == null) {
          // Bad response from pub host.
          return [];
        }
        final parsedVersion = Version.parse(versionString);
        if (parsedVersion.isPreRelease) continue;
        if (package.upgradable != null &&
            parsedVersion <= Version.parse(package.upgradable!.version)) {
          continue;
        }
        // It's not outdated, just mutually incompatible if allowed by the
        // constraint, but still reported as outdated by `dart pub outdated`.
        if (hostedDependency.version.allows(parsedVersion)) {
          continue;
        }

        final publishingDateString = tryGetFromJson<String>(
                version, 'published') ??
            // If the pub host doesn't provide a `published` time, we pretend it
            // was published loong ago.
            DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
        final publishingDate = DateTime.parse(publishingDateString);
        final timeAgo = DateTime.now().difference(publishingDate);
        if (timeAgo < acceptableUpdateDelay) {
          result.add(OutdatedVersionDescription(
              Issue(
                'The constraint `${hostedDependency.version}` on $name does not support the stable version `$versionString`, '
                'that was published ${timeAgo.inDays} days ago. '
                '\n\n When $name is ${acceptableUpdateDelay.inDays} days old, this package will no longer be awarded points in this category.',
                suggestion:
                    'Try running `dart pub upgrade --major-versions $name` to update the constraint.',
              ),
              OutdatedStatus.outdatedByRecent));
        } else {
          final pubspec = Pubspec.fromJson(
              tryGetFromJson<Map<String, dynamic>>(version, 'pubspec')!);
          if (pubspec.hasDartSdkConstraint &&
              !pubspec.dartSdkConstraint!.allows(context.currentSdkVersion)) {
            result.add(OutdatedVersionDescription(
                Issue(
                    'The constraint `${hostedDependency.version}` on $name does not support the stable version `$versionString`, '
                    'but that version doesn\'t support the current Dart SDK version ${context.currentSdkVersion}.'
                    '\n\nWhen a supporting stable sdk is pubslished, this package will no longer be awarded points in this category.'),
                OutdatedStatus.outdatedByPreview));
          } else {
            result.add(OutdatedVersionDescription(
                Issue(
                  'The constraint `${hostedDependency.version}` on $name does not support '
                  'the stable version `$versionString`.',
                  suggestion:
                      'Try running `dart pub upgrade --major-versions $name` to update the constraint.',
                ),
                OutdatedStatus.outdated));
          }
        }
      }
    }
  } on FormatException catch (e) {
    log.warning(
        'Failure when trying to calculate outdated status of $name. $e');
    // Just go with whatever we found at this point - pub servers are not all
    // expected to provide a well-formatted `published` entry.
    return result;
  }
  return result;
}

T maxBy<T>(Iterable<T> e, int Function(T, T) compare) {
  assert(e.isNotEmpty);
  var currentBest = e.first;
  for (final next in e.skip(1)) {
    if (compare(currentBest, next) > 0) {
      currentBest = next;
    }
  }
  return currentBest;
}
