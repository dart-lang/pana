// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Creates a [Explanation] indicating an issue, using [path] to
/// give the location of the issue.
typedef Explainer<N> = Explanation? Function(List<N> path);

/// Returns an [Explainer] if [node] fulfills the predicate (if it violates some
/// property) and `null` otherwise.
///
/// Explainer should give an explanation of the problem.
typedef Predicate<T> = Explainer<T>? Function(T node);

/// The accumulated values of a tagging step.
class TaggingResult {
  final Set<String> tags;
  final List<Explanation> explanations;

  TaggingResult(this.tags, this.explanations);

  factory TaggingResult.merge(Iterable<TaggingResult> results) {
    final tags = <String>{};
    final explanations = <Explanation>[];
    for (final result in results) {
      tags.addAll(result.tags);
      explanations.addAll(result.explanations);
    }
    return TaggingResult(tags, explanations);
  }

  bool get isSuccess => tags.isNotEmpty && explanations.isEmpty;
}

/// Indicates an issue.
class Explanation {
  final String finding;
  final String? explanation;

  /// The tag that this explanation explains why the package didn't get.
  ///
  /// Should be `null` if this is a more general error message not connected to
  /// any certain tag.
  final String? tag;

  Explanation(this.finding, this.explanation, {required this.tag});

  @override
  String toString() => 'Explanation($finding, $explanation)';
}

/// Thrown when tag detection encounters an unrecoverable issue.
class TagException implements Exception {
  final String? message;

  TagException([this.message]);

  @override
  String toString() {
    if (message == null) return 'Exception';
    return 'Exception: $message';
  }
}
