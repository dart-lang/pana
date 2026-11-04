// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../model.dart';
import '../package_context.dart';

const _changeCodesUrl =
    'https://github.com/bmw-tech/dart_apitool/blob/main/readme/change_codes.md';
const _maxInlineChangesPerSection = 30;

/// Creates an informational (0-point) [ReportSection] summarizing the public
/// API diff between the previous published version and the current version.
Future<ReportSection?> apiDiffSection(PackageContext context) async {
  if (!context.options.runApiDiff) {
    return null;
  }
  final result = await context.apiDiffResult;
  if (!result.wasRun) {
    return null;
  }

  if (result.errorReason != null) {
    return ReportSection(
      id: ReportSectionId.apiDiff,
      title: 'Public API changes',
      grantedPoints: 0,
      maxPoints: 0,
      status: ReportStatus.partial,
      summary:
          '### [~] Could not compute public API diff\n\n'
          '${result.errorReason}\n',
    );
  }

  final diff = result.summary;
  if (diff == null) {
    return ReportSection(
      id: ReportSectionId.apiDiff,
      title: 'Public API changes',
      grantedPoints: 0,
      maxPoints: 0,
      status: ReportStatus.passed,
      summary:
          '### [*] First published version\n\n'
          'No previous published version of `${context.pubspec.name}` was found '
          'to compare against.\n',
    );
  }

  final status = diff.isVersionIncrementSufficient
      ? ReportStatus.passed
      : ReportStatus.partial;
  final marker = status == ReportStatus.passed ? '[*]' : '[~]';

  final breakingCount = diff.breakingChanges.length;
  final nonBreakingCount = diff.nonBreakingChanges.length;

  final String headline;
  if (breakingCount == 0 && nonBreakingCount == 0) {
    headline =
        'No public API changes detected compared to `${diff.previousVersion}`';
  } else if (!diff.isVersionIncrementSufficient) {
    headline =
        'Potentially breaking or under-versioned API changes compared to '
        '`${diff.previousVersion}` (expected `>=${diff.minimumExpectedVersion}`, '
        'got `${diff.currentVersion}`)';
  } else if (breakingCount > 0) {
    headline =
        '$breakingCount breaking and $nonBreakingCount non-breaking API '
        '${_pluralize(breakingCount + nonBreakingCount, 'change')} compared to '
        '`${diff.previousVersion}`';
  } else {
    headline =
        '$nonBreakingCount non-breaking API '
        '${_pluralize(nonBreakingCount, 'change')} (0 breaking) compared to '
        '`${diff.previousVersion}`';
  }

  final buffer = StringBuffer();
  buffer.writeln('### $marker $headline\n');
  buffer.writeln(
    'Compared `${context.pubspec.name}` `${diff.previousVersion}` → '
    '`${diff.currentVersion}` '
    '(minimum expected version for detected changes: '
    '`${diff.minimumExpectedVersion}`, required bump: `${diff.requiredVersionBump}`).\n',
  );

  if (diff.breakingChanges.isNotEmpty) {
    buffer.writeln(
      '#### Potentially breaking changes (${diff.breakingChanges.length})\n',
    );
    _writeChangesByScope(
      buffer,
      diff.breakingChanges,
      showTypeBadge: false,
      collapseThreshold: _maxInlineChangesPerSection,
    );
  }

  if (diff.nonBreakingChanges.isNotEmpty) {
    final minorChanges = diff.nonBreakingChanges
        .where((c) => c.type == 'minor')
        .toList();
    final patchChanges = diff.nonBreakingChanges
        .where((c) => c.type != 'minor')
        .toList();

    if (minorChanges.isNotEmpty) {
      buffer.writeln(
        '#### Additions & minor changes (${minorChanges.length})\n',
      );
      _writeChangesByScope(
        buffer,
        minorChanges,
        showTypeBadge: false,
        collapseThreshold: _maxInlineChangesPerSection,
      );
    }

    if (patchChanges.isNotEmpty) {
      buffer.writeln(
        '#### Patch-level API & dependency changes (${patchChanges.length})\n',
      );
      _writeChangesByScope(
        buffer,
        patchChanges,
        showTypeBadge: false,
        collapseThreshold: _maxInlineChangesPerSection,
      );
    }
  }

  if (diff.textDiff != null && diff.textDiff!.trim().isNotEmpty) {
    buffer.writeln('#### Signature diff (`api.txt`)\n');
    buffer.writeln('```diff');
    buffer.writeln(diff.textDiff!.trimRight());
    buffer.writeln('```\n');
  }

  buffer.writeln(
    'To reproduce this public API diff locally, activate '
    '[`api_summary`](https://pub.dev/packages/api_summary) and run:\n'
    '```sh\n'
    'dart pub global run api_summary diff --old <old_package_dir> --new .\n'
    '```\n',
  );

  return ReportSection(
    id: ReportSectionId.apiDiff,
    title: 'Public API changes',
    grantedPoints: 0,
    maxPoints: 0,
    status: status,
    summary: buffer.toString(),
  );
}

void _writeChangesByScope(
  StringBuffer buffer,
  List<ApiChange> changes, {
  required bool showTypeBadge,
  required int collapseThreshold,
}) {
  final grouped = <String, List<ApiChange>>{};
  for (final change in changes) {
    final key = change.scope.isEmpty ? 'Package' : change.scope.join(' › ');
    (grouped[key] ??= []).add(change);
  }

  final lines = <String>[];
  for (final entry in grouped.entries) {
    lines.add('* **${entry.key}**');
    for (final c in entry.value) {
      final isApitoolCode = RegExp(r'^[A-Z]{2}\d{2}$').hasMatch(c.changeCode);
      final codeBadge = isApitoolCode
          ? '[`${c.changeCode}`]($_changeCodesUrl#${c.changeCode.toLowerCase()})'
          : '`${c.changeCode}`';
      final badge = showTypeBadge ? ' (${c.type})' : '';
      lines.add('  * ${c.description} ($codeBadge)$badge');
    }
  }

  if (changes.length > collapseThreshold) {
    buffer.writeln('<details>');
    buffer.writeln(
      '<summary>Showing all ${changes.length} changes across '
      '${grouped.length} ${_pluralize(grouped.length, 'declaration')}</summary>\n',
    );
    buffer.writeln(lines.join('\n'));
    buffer.writeln('\n</details>\n');
  } else {
    buffer.writeln(lines.join('\n'));
    buffer.writeln();
  }
}

String _pluralize(int count, String singular) =>
    count == 1 ? singular : '${singular}s';
