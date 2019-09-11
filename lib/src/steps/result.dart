// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show UnmodifiableListView;
import 'dart:math' show min, max;

import 'package:collection/collection.dart' show UnmodifiableSetView;
import 'package:source_span/source_span.dart';
import 'package:meta/meta.dart' show required, sealed;

import '../model.dart' show Suggestion, SuggestionLevel;
import 'run.dart' show run;
import 'step.dart' show Step;
import 'tags.dart';

/// Data class for holding all analysis results.
@sealed
class Result {
  final Set<String> tags;
  final List<Suggestion> suggestions;

  Result._({
    this.tags,
    this.suggestions,
  });
}

@sealed
class ResultBuilder {
  final String _suggestionCodePrefix;
  final List<Suggestion> _suggestions = [];
  final Set<String> _tags = {};

  ResultBuilder(this._suggestionCodePrefix);

  /// Create a _suggestion_ with severity **error**.
  ///
  /// Severity **error** should be used when:
  ///  * An issue _will_ casuse problems for users of the package,
  ///  * The package is fundamentally broken,
  ///  * The issue is to sever to warrent a [warning] or [hint].
  ///
  /// **Examples** include:
  ///  * Static code errors,
  ///  * Missing dependencies.
  ///
  /// A suggestion have following parameters:
  ///  * [kind], (optional) kind identifier for statistics and grouping,
  ///  * [title], a human-readable title for the suggestion,
  ///  * [description], a human-readable markdown description of the suggestion,
  ///  * [location], (optional) span of source code that caused this suggestion,
  ///  * [penalty], (optional) penalty for package score ranging from 0 to 1.
  void error({
    String kind,
    @required String title,
    @required String description,
    SourceSpan location,
    double penalty = 0,
  }) =>
      _addSuggestion(
        kind,
        SuggestionLevel.error,
        title,
        description,
        location,
        penalty,
      );

  /// Create a _suggestion_ with severity **warning**.
  ///
  /// Severity **warning** should be used when:
  ///  * An issue _may_ cause problems for users of the package,
  ///  * An issue _will_ seriously impair usability of the package,
  ///  * The issue doesn't qualify as [error], and is worse than an [hint].
  ///
  /// **Examples** include:
  ///  * Out-dated dependencies,
  ///  * Version pinning,
  ///  * Unawaited futures,
  ///  * Missing `README.md`.
  ///
  /// A suggestion have following parameters:
  ///  * [kind], (optional) kind identifier for statistics and grouping,
  ///  * [title], a human-readable title for the suggestion,
  ///  * [description], a human-readable markdown description of the suggestion,
  ///  * [location], (optional) span of source code that caused this suggestion,
  ///  * [penalty], (optional) penalty for package score ranging from 0 to 1.
  void warning({
    String kind,
    @required String title,
    @required String description,
    SourceSpan location,
    double penalty = 0,
  }) =>
      _addSuggestion(
        kind,
        SuggestionLevel.warning,
        title,
        description,
        location,
        penalty,
      );

  /// Create a _suggestion_ with severity **hint**.
  ///
  /// Severity **hint** should be used when:
  ///  * An issue may impair usability for users of the package,
  ///  * The packages does not follow best practices,
  ///  * The issue doesn't qualify as [warning] or [error].
  ///
  /// **Examples** include:
  ///  * Few documentation comments,
  ///  * Poorly named variables.
  ///
  /// A suggestion have following parameters:
  ///  * [kind], (optional) kind identifier for statistics and grouping,
  ///  * [title], a human-readable title for the suggestion,
  ///  * [description], a human-readable markdown description of the suggestion,
  ///  * [location], (optional) span of source code that caused this suggestion,
  ///  * [penalty], (optional) penalty for package score ranging from 0 to 1.
  void hint({
    String kind,
    @required String title,
    @required String description,
    SourceSpan location,
    double penalty = 0,
  }) =>
      _addSuggestion(
        kind,
        SuggestionLevel.hint,
        title,
        description,
        location,
        penalty,
      );

  void _addSuggestion(
    String kind,
    String level,
    String title,
    String description,
    SourceSpan loc,
    double penalty,
  ) {
    ArgumentError.checkNotNull(title, 'title');
    ArgumentError.checkNotNull(description, 'decription');
    ArgumentError.checkNotNull(penalty, 'penalty');
    if (title.isEmpty) {
      throw ArgumentError.value(title, 'title', 'cannot be an empty string');
    }
    if (description.isEmpty) {
      throw ArgumentError.value(
          description, 'description', 'cannot be an empty string');
    }

    // We don't want production errors because penalty is out-of-range, instead
    // we just limit to the range and have an assert that it's in our range.
    assert(0.0 <= penalty && penalty <= 1.0);
    penalty = min(max(penalty, 1.0), 0.0);

    _suggestions.add(Suggestion(
      kind != null ? '$_suggestionCodePrefix.$kind' : _suggestionCodePrefix,
      level,
      title,
      description,
      file: loc?.sourceUrl?.path,
      score: 100 - (penalty * 100),
    ));
  }

  /// Add [tag] to the result for the current package.
  ///
  /// On `pub.dev` package search queries can be filter by tags, such that it is
  /// possible to limit a search query to packages with a given tag. Or exclude
  /// packages which has a given tag.
  ///
  /// Tags must match a [TagPattern] registered in [tagPatterns], this ensures
  /// that all tags are documented, and prevents the namespace from overlapping.
  void tag(String tag) {
    if (!isValidTag(tag)) {
      throw ArgumentError.value(
          tag, 'tag', 'tag is invalid, ensure the pattern is registered');
    }
    _tags.add(tag);
  }

  /// Create a [Result] from a list of [builders].
  static Result build(Iterable<ResultBuilder> builders) {
    return Result._(
      tags: UnmodifiableSetView(builders
          .map((b) => b._tags)
          .reduce((s1, s2) => {...s1, ...s2})
          .toSet()),
      suggestions: UnmodifiableListView(
        builders
            .map((b) => b._suggestions)
            .reduce((s1, s2) => [...s1, ...s2])
            .toSet()
            .toList(),
      ),
    );
  }
}

/// The [BreakStep] exception can be thrown from an [Step] to abort analysis.
///
/// If the [Step] was invoked from [run] the suggestion from the [BreakStep]
/// exception will be added to the [ResultBuilder]. This is a convinient way to
/// report a suggestion and return in a single statement, that even works from
/// an auxiliary method.
///
/// Step authors can also catch a [BreakStep] exception from a utility function
/// and either report it with [report], `rethrow` or ignore it. When caught
/// step authors can use the [kind] to determine which action to take.
class BreakStep implements Exception {
  final String kind;
  final String _level;
  final String _title;
  final String _description;
  final SourceSpan _loc;
  final double _penalty;

  BreakStep._({
    this.kind,
    String level,
    @required String title,
    @required String description,
    SourceSpan location,
    double penalty = 0,
  })  : _title = title,
        _level = level,
        _description = description,
        _loc = location,
        _penalty = penalty {
    ArgumentError.checkNotNull(title, 'title');
    ArgumentError.checkNotNull(description, 'decription');
    ArgumentError.checkNotNull(penalty, 'penalty');
    if (title.isEmpty) {
      throw ArgumentError.value(title, 'title', 'cannot be an empty string');
    }
    if (description.isEmpty) {
      throw ArgumentError.value(
          description, 'description', 'cannot be an empty string');
    }

    // We don't want production errors because penalty is out-of-range, instead
    // we just limit to the range and have an assert that it's in our range.
    assert(0.0 <= penalty && penalty <= 1.0);
  }

  /// Throw a [BreakStep] with a suggestion for [ResultBuilder.error].
  static void error({
    String kind,
    @required String title,
    @required String description,
    SourceSpan location,
    double penalty = 0,
  }) =>
      throw BreakStep._(
        kind: kind,
        level: SuggestionLevel.error,
        title: title,
        description: description,
        location: location,
        penalty: penalty,
      );

  /// Throw a [BreakStep] with a suggestion for [ResultBuilder.warning].
  static void warning({
    String kind,
    @required String title,
    @required String description,
    SourceSpan location,
    double penalty = 0,
  }) =>
      throw BreakStep._(
        kind: kind,
        level: SuggestionLevel.warning,
        title: title,
        description: description,
        location: location,
        penalty: penalty,
      );

  /// Throw a [BreakStep] with a suggestion for [ResultBuilder.hint].
  static void hint({
    String kind,
    @required String title,
    @required String description,
    SourceSpan location,
    double penalty = 0,
  }) =>
      throw BreakStep._(
        kind: kind,
        level: SuggestionLevel.hint,
        title: title,
        description: description,
        location: location,
        penalty: penalty,
      );

  /// Add this suggestion to [resultBuilder].
  void report(ResultBuilder resultBuilder) => resultBuilder._addSuggestion(
        kind,
        _level,
        _title,
        _description,
        _loc,
        _penalty,
      );
}
