// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show utf8;
import 'package:file/file.dart' show File;
import 'package:source_span/source_span.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import '../step.dart';

final _changelogFilePattern = RegExp(r'^CHANGELOG($|\.)', caseSensitive: false);

/// The changelog [Step] will check that:
///  1. A changelog file exists,
///  2. The changelog is valid UTF-8 encoded,
///  3. The changelog mentioned the current version.
final changelog = Step('changelog', (ctx) async {
  // Find the changelog file
  final changelogFile = await ctx.packageFolder.list().firstWhere(
        (e) => e is File && _changelogFilePattern.hasMatch(e.basename),
        orElse: () => null,
      ) as File;
  // If there is no changelog file, then we'll leave a hint and be done.
  if (changelogFile == null) {
    BreakStep.hint(
      kind: 'changelog-not-found',
      title: 'CHANGELOG.md missing',
      description: 'Consider including a `CHANGELOG.md` file outlining the '
          'changes from one version to the next.',
      penalty: 0.1,
    );
  }

  final pubspecFile = ctx.packageFolder.childFile('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    return; // Someone else will handle this
  }
  final pubspec = Pubspec.parse(
    await pubspecFile.readAsString(),
    lenient: true,
    sourceUrl: pubspecFile.path,
  );

  // Read the changelog file
  final changelogBytes = await changelogFile.readAsBytes();
  String changelog;
  try {
    changelog = utf8.decode(changelogBytes);
  } on FormatException {
    ctx.add.warning(
      kind: 'changelog-encoding',
      title: 'Changelog encoding',
      description: 'Use utf8 encoding for `${changelogFile.basename}`',
      location: SourceFile.decoded(
        changelogBytes,
        url: changelogFile.path,
      ).span(0),
      penalty: 0.5,
    );
    // Do a best effort decoding and continue
    changelog = utf8.decode(changelogBytes, allowMalformed: true);
  }

  if (!changelog.contains(pubspec.version.toString())) {
    final f = SourceFile.fromString(
      changelog,
      url: changelogFile.path,
    );
    ctx.add.hint(
      kind: 'changelog-entry-missing',
      title: 'Changelog entry missing',
      description: 'The changelog in `${changelogFile.basename}` is missing an '
          'entry for the current version `${pubspec.version}`',
      location: f.span(0, 0),
      penalty: 0.1,
    );
  }
});
