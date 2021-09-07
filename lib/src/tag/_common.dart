// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Creates a [Explanation] indicating an issue, using [path] to give the location
/// of the issue.
typedef Explainer<N> = Explanation? Function(List<N> path);

/// Returns an [Explainer] if node fullfills the predicate (if it violates some
/// property) and `null` otherwise.
///
/// Explainer should give an explanation of the problem.
typedef Predicate<T> = Explainer<T>? Function(T node);

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

/// Returns a parsed (not resolved) compilation unit of [uri] created by
/// [analysisSession].
///
/// Returns `null` in case of any errors.
///
/// Returns `null` if [uri] points to a part file.
CompilationUnit? parsedUnitFromUri(AnalysisSession analysisSession, Uri uri) {
  final path = analysisSession.uriConverter.uriToPath(uri);
  if (path == null) {
    // Could not resolve uri.
    // Probably a missing/broken dependency.
    throw TagException('Broken import $uri');
  }
  final unitResult = analysisSession.getParsedUnit(path) as ParsedUnitResult;
  if (unitResult.errors.isNotEmpty) return null;
  if (unitResult.isPart) {
    // Part files cannot contain import/export directives or language
    // directives.
    return null;
  }
  return unitResult.unit;
}
